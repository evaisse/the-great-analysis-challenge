#!/usr/bin/env python3
"""
Chess Engine Test Harness
Tests multiple chess engine implementations against the specification
"""

import subprocess
import json
import time
import sys
import os
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import argparse

# Ensure repository root is importable
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

# Add scripts directory to path to import shared module
SCRIPTS_DIR = REPO_ROOT / 'scripts'
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from chess_metadata import get_metadata

TRACK_TO_SUITE = {
    "v1": "test/test_suite.json",
    "v2-foundation": "test/suites/v2_foundation.json",
    "v2-functional": "test/suites/v2_functional.json",
    "v2-system": "test/suites/v2_system.json",
    "v2-full": "test/suites/v2_full.json",
}

class ChessEngineTester:
    def __init__(self, implementation_path: str, metadata: Dict, docker_image: Optional[str] = None):
        self.path = implementation_path
        self.metadata = metadata
        self.docker_image = docker_image
        self.process = None
        self.results = {
            "passed": [],
            "failed": [],
            "performance": {},
            "errors": []
        }
        
    def start(self):
        """Start the chess engine process"""
        run_command = self.metadata.get("run", "").split()
        if not run_command:
            raise ValueError(f"No run command specified for {self.path}")

        command = run_command
        if self.docker_image:
            run_command_shell = self.metadata.get("run", "")
            command = [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "-i",
                "-v",
                f"{REPO_ROOT}:/repo:ro",
                self.docker_image,
                "sh",
                "-c",
                f"cd /app && {run_command_shell}",
            ]

        try:
            self.process = subprocess.Popen(
                command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=0,
                cwd=self.path if not self.docker_image else None,
            )
            self._drain_startup_output()
        except Exception as e:
            self.results["errors"].append(f"Failed to start: {e}")
            return False
        return True

    def _drain_startup_output(self, max_wait: float = 1.5, quiet_window: float = 0.2):
        """Drain banner/board output emitted at startup before first command."""
        if not self.process or not self.process.stdout:
            return

        try:
            import fcntl
            import os
            import select

            fd = self.process.stdout.fileno()
            fl = fcntl.fcntl(fd, fcntl.F_GETFL)
            try:
                fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
                start = time.time()
                last_data = start
                while time.time() - start < max_wait:
                    ready, _, _ = select.select([self.process.stdout], [], [], 0.05)
                    if ready:
                        chunk = self.process.stdout.read(1024)
                        if chunk:
                            last_data = time.time()
                    if time.time() - last_data >= quiet_window:
                        break
            finally:
                fcntl.fcntl(fd, fcntl.F_SETFL, fl)
        except Exception:
            # Startup drainage is best-effort; ignore portability/runtime errors.
            return
    
    def send_command(self, command: str, timeout: float = 10.0) -> str:
        """Send command and get response with non-blocking reads"""
        if not self.process:
            return ""
            
        try:
            import fcntl
            import os
            import select

            # Clear any pending output using non-blocking reads
            fd = self.process.stdout.fileno()
            fl = fcntl.fcntl(fd, fcntl.F_GETFL)
            fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
            try:
                while self.process.stdout.read(1024): pass
            except:
                pass
            fcntl.fcntl(fd, fcntl.F_SETFL, fl)

            # Send command
            self.process.stdin.write(command + "\n")
            self.process.stdin.flush()
            
            start_time = time.time()
            output_lines = []
            end_seen_at = None
            
            # Keywords that signal the end of an engine response
            end_keywords = [
                "OK:", "ERROR:", "CHECKMATE:", "STALEMATE:", 
                "FEN:", "AI:", "EVALUATION:", "HASH:", 
                "REPETITION:", "DRAW:", "DRAWS:", "CONCURRENCY:",
                "960:",
                "UCIOK", "READYOK", "BESTMOVE", "INFO ", "ID NAME", "ID AUTHOR",
                "PGN", "TRACE",
            ]
            
            while time.time() - start_time < timeout:
                if self.process.poll() is not None:
                    break
                
                # Use select to wait for data with a short timeout
                ready, _, _ = select.select([self.process.stdout], [], [], 0.1)
                
                if ready:
                    line = self.process.stdout.readline()
                    if line:
                        stripped_line = line.strip()
                        output_lines.append(stripped_line)
                        if any(kw in stripped_line.upper() for kw in end_keywords):
                            end_seen_at = time.time()

                # Give a short grace period after an end marker so trailing lines
                # from the same response (e.g. board + metadata) are captured.
                if end_seen_at is not None and (time.time() - end_seen_at) >= 0.12:
                    break

            return "\n".join(output_lines)
            
        except Exception as e:
            self.results["errors"].append(f"Command error: {e}")
            return ""
    
    def stop(self):
        """Stop the chess engine process"""
        if self.process:
            self.send_command("quit", timeout=1.0)
            time.sleep(0.5)
            if self.process.poll() is None:
                self.process.terminate()
            self.process = None

class TestSuite:
    def __init__(self, suite_path: str = "test/test_suite.json"):
        self.suite_path = suite_path
        self.tests = []
        self.load_tests()
        
    def load_tests(self):
        """Load all test cases from JSON suite"""
        if not os.path.exists(self.suite_path):
            print(f"Warning: Test suite file not found at {self.suite_path}")
            return

        try:
            with open(self.suite_path, 'r') as f:
                data = json.load(f)
                
            categories = data.get("test_categories", {})
            for cat_id, cat_info in categories.items():
                cat_tests = cat_info.get("tests", [])
                for test in cat_tests:
                    # Add category info to test
                    test["category"] = cat_id
                    self.tests.append(test)
                    
            print(f"Loaded {len(self.tests)} tests from {self.suite_path}")
        except Exception as e:
            print(f"Error loading test suite: {e}")

    def _resolve_commands(self, cmd_info) -> List[str]:
        """Resolve one command entry into one or more concrete commands."""
        if isinstance(cmd_info, str):
            return [cmd_info]

        if not isinstance(cmd_info, dict):
            return [str(cmd_info)]

        if "fixture_file" in cmd_info:
            fixture_path = Path(cmd_info["fixture_file"])
            if not fixture_path.is_absolute():
                fixture_path = REPO_ROOT / fixture_path

            line_template = cmd_info.get("line_template", "{line}")
            try:
                with fixture_path.open("r", encoding="utf-8") as handle:
                    commands = []
                    for idx, raw_line in enumerate(handle):
                        line = raw_line.strip()
                        if not line or line.startswith("#"):
                            continue
                        commands.append(line_template.format(line=line, index=idx))
                    return commands
            except Exception as exc:
                # Surface fixture issues as synthetic commands, so the test fails with context.
                return [f"__FIXTURE_ERROR__: {fixture_path}: {exc}"]

        cmd = cmd_info.get("cmd", "")
        if not cmd:
            return []
        return [cmd]

    def run_test(self, tester: ChessEngineTester, test: Dict) -> bool:
        """Run a single test case from the suite definition"""
        try:
            all_output = []
            start_time = time.time()
            
            commands = test.get("commands", [])
            for cmd_info in commands:
                resolved_commands = self._resolve_commands(cmd_info)
                for cmd in resolved_commands:
                    output = tester.send_command(cmd, test.get("timeout", 1000) / 1000.0)
                    all_output.append(output)
                
            elapsed = time.time() - start_time
            full_output = "\n".join(all_output)
            
            # Pattern-based validation
            patterns = test.get("expected_patterns", [])
            # For backward compatibility with older tests that used lambda validate
            if "validate" in test and callable(test["validate"]):
                success = test["validate"](full_output)
            else:
                success = all(p.upper() in full_output.upper() for p in patterns)
            
            if success:
                tester.results["passed"].append(test["name"])
                tester.results["performance"][test["name"]] = elapsed
                return True
            else:
                tester.results["failed"].append({
                    "test": test["name"],
                    "output": full_output[:1000]
                })
                return False
                
        except Exception as e:
            tester.results["failed"].append({
                "test": test["name"],
                "error": str(e)
            })
            return False

def find_implementations(base_dir: str) -> List[Tuple[str, Dict]]:
    """Find all chess implementations with metadata"""
    implementations = []
    base_path = Path(base_dir)
    
    # Look for directories containing a Dockerfile
    for dockerfile in base_path.rglob("Dockerfile"):
        impl_dir = dockerfile.parent
        # Skip top-level Dockerfile if it exists
        if impl_dir == base_path:
            continue
            
        metadata = get_metadata(str(impl_dir))
        
        if metadata:
            implementations.append((str(impl_dir), metadata))
            
    return implementations

def run_performance_tests(tester: ChessEngineTester) -> Dict:
    """Run performance benchmarks"""
    perf_results = {}
    
    # Test move generation speed
    tester.send_command("new")
    start = time.time()
    for _ in range(10):
        tester.send_command("move e2e4")
        tester.send_command("undo")
    perf_results["move_speed"] = (time.time() - start) / 10
    
    # Test AI at different depths
    for depth in [1, 3, 5]:
        if depth <= tester.metadata.get("max_ai_depth", 5):
            tester.send_command("new")
            start = time.time()
            output = tester.send_command(f"ai {depth}", timeout=30)
            if "AI:" in output:
                perf_results[f"ai_depth_{depth}"] = time.time() - start
    
    return perf_results

def generate_report(results: Dict[str, Dict]) -> str:
    """Generate test report"""
    report = []
    report.append("=" * 80)
    report.append("CHESS ENGINE TEST HARNESS REPORT")
    report.append("=" * 80)
    report.append("")
    
    # Summary table
    report.append("SUMMARY")
    report.append("-" * 40)
    report.append(f"{'Language':<15} {'Passed':<10} {'Failed':<10} {'Errors':<10}")
    report.append("-" * 40)
    
    for impl, data in results.items():
        lang = data.get("metadata", {}).get("language", "Unknown")
        passed = len(data["results"]["passed"])
        failed = len(data["results"]["failed"])
        errors = len(data["results"]["errors"])
        report.append(f"{lang:<15} {passed:<10} {failed:<10} {errors:<10}")
    
    report.append("")
    
    # Detailed results
    for impl, data in results.items():
        report.append(f"\n{'=' * 40}")
        report.append(f"Implementation: {impl}")
        report.append(f"Language: {data.get('metadata', {}).get('language', 'Unknown')}")
        report.append(f"{'=' * 40}")
        
        if data["results"]["passed"]:
            report.append("\nPASSED TESTS:")
            for test in data["results"]["passed"]:
                time_taken = data["results"]["performance"].get(test, 0)
                report.append(f"  ✓ {test} ({time_taken:.2f}s)")
        
        if data["results"]["failed"]:
            report.append("\nFAILED TESTS:")
            for failure in data["results"]["failed"]:
                report.append(f"  ✗ {failure['test']}")
                if "error" in failure:
                    report.append(f"    Error: {failure['error']}")
                elif "output" in failure:
                    report.append(f"    Output: {failure['output'][:100]}...")
        
        if data["results"]["errors"]:
            report.append("\nERRORS:")
            for error in data["results"]["errors"]:
                report.append(f"  ! {error}")
        
        if "performance" in data:
            report.append("\nPERFORMANCE:")
            for metric, value in data["performance"].items():
                if metric.startswith("ai_depth"):
                    report.append(f"  {metric}: {value:.2f}s")
                elif metric == "move_speed":
                    report.append(f"  Average move time: {value*1000:.1f}ms")
    
    report.append("\n" + "=" * 80)
    return "\n".join(report)

def main():
    parser = argparse.ArgumentParser(
        description="Chess Engine Protocol Compliance Testing",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        "--dir", 
        default="implementations", 
        metavar="DIR",
        help="Directory containing implementations (default: implementations)"
    )
    
    parser.add_argument(
        "--suite",
        metavar="FILE",
        help="Path to a suite JSON file (defaults to v1 suite)"
    )

    parser.add_argument(
        "--track",
        choices=sorted(TRACK_TO_SUITE.keys()),
        help="Named track to run (overridden by --suite when both are provided)"
    )

    parser.add_argument(
        "--docker-image",
        metavar="IMAGE",
        help="Run engine inside this Docker image (docker run -i IMAGE ...)"
    )

    parser.add_argument(
        "--category",
        metavar="ID",
        help="Only run tests from one category id"
    )

    parser.add_argument(
        "--impl", 
        metavar="PATH",
        help="Test specific implementation directory"
    )
    
    parser.add_argument(
        "--test", 
        metavar="NAME",
        help="Run specific test case"
    )
    
    parser.add_argument(
        "--performance", 
        action="store_true", 
        help="Run additional performance benchmarks"
    )
    
    parser.add_argument(
        "--output", 
        metavar="FILE",
        help="Save report to file"
    )
    
    args = parser.parse_args()

    suite_path = args.suite
    if not suite_path and args.track:
        suite_path = TRACK_TO_SUITE[args.track]
    if not suite_path:
        suite_path = TRACK_TO_SUITE["v1"]
    
    # Find implementations
    if args.impl:
        metadata = get_metadata(args.impl)
        if metadata:
            implementations = [(args.impl, metadata)]
        else:
            print(f"No metadata found in {args.impl}")
            return 1
    else:
        implementations = find_implementations(args.dir)
    
    if not implementations:
        print(f"No implementations found in {args.dir}")
        return 1
    
    print(f"Found {len(implementations)} implementation(s)")
    
    # Test each implementation
    suite = TestSuite(suite_path)
    all_results = {}
    
    for impl_path, metadata in implementations:
        print(f"\nTesting {metadata.get('language', 'Unknown')} implementation at {impl_path}")
        print("-" * 40)
        
        docker_image = args.docker_image
        if not docker_image and args.impl:
            docker_image = f"chess-{Path(args.impl).name}"
        tester = ChessEngineTester(impl_path, metadata, docker_image=docker_image)
        
        # Build if necessary
        if not tester.docker_image and "build" in metadata and metadata["build"] != "make build":
            cmd = metadata["build"]
            print(f"🔧 Running: {cmd}")
            subprocess.run(cmd, cwd=impl_path, check=True, shell=True)
        
        # Start engine
        if not tester.start():
            print(f"Failed to start implementation at {impl_path}")
            all_results[impl_path] = {
                "metadata": metadata,
                "results": tester.results
            }
            continue
        
        # Run tests
        if args.test:
            # Run specific test
            test = next((t for t in suite.tests if t["name"] == args.test), None)
            if test:
                print(f"Running test: {test['name']}")
                success = suite.run_test(tester, test)
                print(f"  {'✓ PASSED' if success else '✗ FAILED'}")
        else:
            # Run all tests
            for test in suite.tests:
                if args.category and test.get("category") != args.category:
                    continue
                if test.get("optional") and test["name"] not in metadata.get("features", []):
                    continue
                    
                print(f"Running test: {test['name']}", end="")
                success = suite.run_test(tester, test)
                print(f" {'✓' if success else '✗'}")
        
        # Run performance tests
        if args.performance:
            print("\nRunning performance tests...")
            perf_results = run_performance_tests(tester)
            all_results[impl_path] = {
                "metadata": metadata,
                "results": tester.results,
                "performance": perf_results
            }
        else:
            all_results[impl_path] = {
                "metadata": metadata,
                "results": tester.results
            }
        
        # Stop engine
        tester.stop()
    
    # Generate report
    report = generate_report(all_results)
    print("\n" + report)
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"\nReport saved to {args.output}")
    
    # Return exit code based on results
    total_failed = sum(len(r["results"]["failed"]) for r in all_results.values())
    return 0 if total_failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
