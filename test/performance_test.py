#!/usr/bin/env python3
"""Performance benchmark runner for chess implementations.

Benchmarked phases are intentionally separated:
1. Docker image build (`make image DIR=<impl>`)
2. Compilation only (`make build DIR=<impl>`)
3. Static analysis only (`make analyze DIR=<impl>`)
4. Shared chess-engine suite only (`make test-chess-engine DIR=<impl>`)
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

# Ensure repository root is importable
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from chess_metadata import get_metadata

try:
    import psutil

    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False


class PerformanceMonitor:
    """Best-effort host-side memory/cpu monitor for each benchmark phase."""

    def __init__(self) -> None:
        self.memory_samples: List[float] = []
        self.cpu_samples: List[float] = []
        self.monitoring = False
        self.monitor_thread: threading.Thread | None = None

    def start(self) -> None:
        if not PSUTIL_AVAILABLE:
            return

        self.monitoring = True
        self.memory_samples.clear()
        self.cpu_samples.clear()
        self.monitor_thread = threading.Thread(target=self._loop, daemon=True)
        self.monitor_thread.start()

    def stop(self) -> Dict:
        if not PSUTIL_AVAILABLE:
            return {
                "memory_mb": 0,
                "peak_memory_mb": 0,
                "avg_memory_mb": 0,
                "avg_cpu_percent": 0,
                "psutil_available": False,
            }

        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=1.0)

        if not self.memory_samples:
            return {
                "memory_mb": 0,
                "peak_memory_mb": 0,
                "avg_memory_mb": 0,
                "avg_cpu_percent": 0,
                "psutil_available": True,
            }

        return {
            "memory_mb": self.memory_samples[-1],
            "peak_memory_mb": max(self.memory_samples),
            "avg_memory_mb": sum(self.memory_samples) / len(self.memory_samples),
            "avg_cpu_percent": sum(self.cpu_samples) / len(self.cpu_samples)
            if self.cpu_samples
            else 0,
            "psutil_available": True,
            "samples": len(self.memory_samples),
        }

    def _loop(self) -> None:
        while self.monitoring:
            try:
                process = psutil.Process()
                memory_mb = process.memory_info().rss / (1024 * 1024)
                cpu_percent = process.cpu_percent()

                for child in process.children(recursive=True):
                    try:
                        memory_mb += child.memory_info().rss / (1024 * 1024)
                        cpu_percent += child.cpu_percent()
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        continue

                self.memory_samples.append(memory_mb)
                self.cpu_samples.append(cpu_percent)
                time.sleep(0.1)
            except Exception:
                break


def discover_implementations(base_dir: Path) -> List[Tuple[Path, Dict]]:
    implementations: List[Tuple[Path, Dict]] = []

    impl_root = base_dir / "implementations"
    if not impl_root.exists():
        return implementations

    for impl_dir in sorted(impl_root.iterdir()):
        if not impl_dir.is_dir():
            continue
        if not (impl_dir / "Dockerfile").exists():
            continue

        metadata = get_metadata(str(impl_dir))
        if metadata:
            implementations.append((impl_dir, metadata))

    return implementations


def run_make_target(target: str, impl_name: str, timeout: int) -> subprocess.CompletedProcess:
    cmd = ["make", target, f"DIR={impl_name}"]
    print(f"🔧 Running: {' '.join(cmd)}")
    return subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


class ImplementationBenchmark:
    def __init__(self, impl_path: Path, metadata: Dict, timeout: int = 1800):
        self.impl_path = impl_path
        self.metadata = metadata
        self.impl_name = impl_path.name
        self.language = metadata.get("language", self.impl_name)
        self.timeout = timeout
        self.phase_timeout = max(30, min(900, timeout // 2))

        self.results: Dict = {
            "language": self.language,
            "path": str(self.impl_path),
            "metadata": metadata,
            "timings": {},
            "memory": {},
            "docker": {},
            "test_results": {"passed": [], "failed": []},
            "errors": [],
            "status": "pending",
        }

    def run(self) -> Dict:
        print("\n" + "=" * 60)
        print(f"Benchmarking {self.language} ({self.impl_name})")
        print("=" * 60)

        phases = [
            ("image", "image_seconds"),
            ("build", "build_seconds"),
            ("analyze", "analyze_seconds"),
            ("test-chess-engine", "test_seconds"),
        ]

        for phase_name, timing_key in phases:
            success = self._run_phase(phase_name, timing_key)
            if not success:
                self.results["status"] = "failed"
                return self.results

        self.results["status"] = "completed"
        return self.results

    def _run_phase(self, phase_name: str, timing_key: str) -> bool:
        monitor = PerformanceMonitor()
        monitor.start()

        start = time.time()
        try:
            result = run_make_target(phase_name, self.impl_name, self.phase_timeout)
            elapsed = time.time() - start
        except subprocess.TimeoutExpired:
            elapsed = time.time() - start
            self.results["timings"][timing_key] = elapsed
            self.results["memory"][phase_name] = monitor.stop()
            self.results["errors"].append(f"{phase_name} timeout after {elapsed:.1f}s")
            self.results["test_results"]["failed"].append(phase_name)
            print(f"❌ {phase_name} timed out after {elapsed:.1f}s")
            return False

        self.results["timings"][timing_key] = elapsed
        self.results["memory"][phase_name] = monitor.stop()

        if result.returncode == 0:
            self.results["test_results"]["passed"].append(phase_name)
            print(f"✅ {phase_name} completed in {elapsed:.2f}s")

            if phase_name == "image":
                self.results["docker"]["build_success"] = True
                self.results["docker"]["build_time"] = elapsed
            if phase_name == "test-chess-engine":
                self.results["docker"]["test_success"] = True
                self.results["docker"]["test_time"] = elapsed

            return True

        stdout = (result.stdout or "")[-2000:]
        stderr = (result.stderr or "")[-2000:]

        self.results["test_results"]["failed"].append(phase_name)
        self.results["errors"].append(
            f"{phase_name} failed (exit code {result.returncode})"
        )
        if stdout.strip():
            self.results["errors"].append(f"{phase_name} stdout tail: {stdout.strip()}")
        if stderr.strip():
            self.results["errors"].append(f"{phase_name} stderr tail: {stderr.strip()}")

        if phase_name == "image":
            self.results["docker"]["build_success"] = False
            self.results["docker"]["build_time"] = elapsed
        if phase_name == "test-chess-engine":
            self.results["docker"]["test_success"] = False
            self.results["docker"]["test_time"] = elapsed

        print(f"❌ {phase_name} failed in {elapsed:.2f}s")
        return False


def format_time(seconds: float | None) -> str:
    if seconds is None:
        return "-"
    return f"{seconds:.1f}s"


def generate_report(results: List[Dict]) -> str:
    lines: List[str] = []
    lines.append("=" * 80)
    lines.append("CHESS ENGINE PERFORMANCE TEST REPORT")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("=" * 80)
    lines.append("")

    lines.append("SUMMARY")
    lines.append("-" * 80)
    lines.append(
        f"{'Language':<12} {'Status':<10} {'Image':<8} {'Build':<8} {'Analyze':<8} {'Test':<8} {'PeakMem':<10}"
    )
    lines.append("-" * 80)

    for result in sorted(results, key=lambda x: str(x.get("language", ""))):
        timings = result.get("timings", {})
        memory = result.get("memory", {})
        peak_mem = 0.0
        for phase in memory.values():
            if isinstance(phase, dict):
                peak_mem = max(peak_mem, float(phase.get("peak_memory_mb", 0)))

        lines.append(
            f"{str(result.get('language', 'unknown'))[:11]:<12} "
            f"{str(result.get('status', 'unknown'))[:9]:<10} "
            f"{format_time(timings.get('image_seconds')):<8} "
            f"{format_time(timings.get('build_seconds')):<8} "
            f"{format_time(timings.get('analyze_seconds')):<8} "
            f"{format_time(timings.get('test_seconds')):<8} "
            f"{peak_mem:>7.0f}MB"
        )

    lines.append("")
    for result in results:
        lines.append("=" * 60)
        lines.append(f"DETAILS: {result.get('language', 'unknown')}")
        lines.append("=" * 60)

        timings = result.get("timings", {})
        for key, value in timings.items():
            lines.append(f"- {key}: {value:.2f}s")

        errors = result.get("errors", [])
        if errors:
            lines.append("- Errors:")
            for error in errors[:10]:
                lines.append(f"  - {error}")
            if len(errors) > 10:
                lines.append(f"  - ... and {len(errors) - 10} more")

    lines.append("=" * 80)
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Chess Engine Performance Testing Suite",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python3 test/performance_test.py\n"
            "  python3 test/performance_test.py --impl implementations/rust\n"
            "  python3 test/performance_test.py --output report.txt --json results.json\n"
            "  python3 test/performance_test.py --timeout 1800\n"
        ),
    )

    parser.add_argument("--impl", metavar="PATH", help="Specific implementation path")
    parser.add_argument("--output", metavar="FILE", help="Save detailed text report")
    parser.add_argument("--json", metavar="FILE", help="Save JSON report")
    parser.add_argument(
        "--timeout",
        type=int,
        default=1800,
        metavar="SECONDS",
        help="Overall timeout in seconds (default: 1800)",
    )

    args = parser.parse_args()

    if args.impl:
        impl_path = Path(args.impl)
        metadata = get_metadata(str(impl_path))
        if not metadata:
            print(f"❌ No metadata found in {args.impl}")
            return 1
        implementations = [(impl_path, metadata)]
    else:
        implementations = discover_implementations(REPO_ROOT)

    if not implementations:
        print("❌ No implementations found")
        return 1

    print("🚀 Chess Engine Performance Testing Suite")
    print("=" * 60)
    print(f"Found {len(implementations)} implementation(s)")

    results: List[Dict] = []
    started = time.time()

    for impl_path, metadata in implementations:
        if time.time() - started > args.timeout:
            print(f"⏰ Overall timeout reached ({args.timeout}s)")
            break

        bench = ImplementationBenchmark(impl_path, metadata, args.timeout)
        result = bench.run()
        results.append(result)

    report = generate_report(results)
    print("\n" + report)

    if args.output:
        Path(args.output).write_text(report)
        print(f"📄 Text report saved to {args.output}")

    valid_results = []
    skipped_results = []

    for result in results:
        status = result.get("status")
        timings = result.get("timings", {})
        build_seconds = timings.get("build_seconds")
        test_seconds = timings.get("test_seconds")

        if (
            status == "completed"
            and build_seconds is not None
            and build_seconds >= 0
            and test_seconds is not None
            and test_seconds >= 0
        ):
            valid_results.append(result)
        else:
            reason = []
            if status != "completed":
                reason.append(f"status={status}")
            if build_seconds is None:
                reason.append("missing build_seconds")
            if test_seconds is None:
                reason.append("missing test_seconds")
            skipped_results.append((result.get("language", "unknown"), ", ".join(reason)))

    if args.json:
        if valid_results:
            Path(args.json).write_text(json.dumps(valid_results, indent=2))
            print(
                f"📄 JSON results saved to {args.json} ({len(valid_results)} valid benchmark(s))"
            )
        else:
            print("⚠️ No valid benchmarks to save to JSON")

        if skipped_results:
            print("⚠️ Skipped incomplete/failed benchmark(s):")
            for language, reason in skipped_results:
                print(f"  - {language}: {reason}")

    failed_count = sum(1 for result in results if result.get("status") != "completed")
    if failed_count > 0:
        print(f"\n❌ {failed_count} implementation(s) failed benchmarking")
        return 1

    print(f"\n✅ All {len(results)} benchmark(s) completed successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
