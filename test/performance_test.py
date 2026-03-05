#!/usr/bin/env python3
"""
Chess Engine Performance Testing Script

This script runs comprehensive performance tests against chess engine implementations:
- Clears Docker build cache
- Measures task timing for build, analyze, test, and test-chess-engine
- Monitors memory consumption
- Uses existing test harness for consistent chess client testing
"""

import subprocess
import json
import time
import sys
import os
import threading
import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import argparse
from datetime import datetime

# Ensure repository root is importable
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

# Add scripts directory to path to import shared module
SCRIPTS_DIR = REPO_ROOT / 'scripts'
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from chess_metadata import get_metadata

# Try to import psutil for memory monitoring
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    print("⚠️  psutil not available - memory monitoring disabled")

# Import existing test harness
from test_harness import ChessEngineTester, TestSuite, find_implementations, TRACK_TO_SUITE
from code_size_metrics import collect_metrics_for_impl

class PerformanceMonitor:
    """Monitor system performance during tests"""
    
    def __init__(self):
        self.memory_samples = []
        self.cpu_samples = []
        self.monitoring = False
        self.monitor_thread = None
        
    def start_monitoring(self):
        """Start monitoring system resources"""
        if not PSUTIL_AVAILABLE:
            return
            
        self.monitoring = True
        self.memory_samples.clear()
        self.cpu_samples.clear()
        self.monitor_thread = threading.Thread(target=self._monitor_loop)
        self.monitor_thread.daemon = True
        self.monitor_thread.start()
        
    def stop_monitoring(self) -> Dict:
        """Stop monitoring and return statistics"""
        if not PSUTIL_AVAILABLE:
            return {"memory_mb": 0, "peak_memory_mb": 0, "avg_cpu_percent": 0, "psutil_available": False}
            
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=1.0)
            
        if not self.memory_samples:
            return {"memory_mb": 0, "peak_memory_mb": 0, "avg_cpu_percent": 0, "psutil_available": True}
            
        return {
            "memory_mb": self.memory_samples[-1],
            "peak_memory_mb": max(self.memory_samples),
            "avg_memory_mb": sum(self.memory_samples) / len(self.memory_samples),
            "avg_cpu_percent": sum(self.cpu_samples) / len(self.cpu_samples) if self.cpu_samples else 0,
            "samples": len(self.memory_samples),
            "psutil_available": True
        }
        
    def _monitor_loop(self):
        """Background monitoring loop"""
        if not PSUTIL_AVAILABLE:
            return
            
        while self.monitoring:
            try:
                # Get current process and children memory usage
                process = psutil.Process()
                memory_mb = process.memory_info().rss / (1024 * 1024)
                cpu_percent = process.cpu_percent()
                
                # Include children processes
                for child in process.children(recursive=True):
                    try:
                        memory_mb += child.memory_info().rss / (1024 * 1024)
                        cpu_percent += child.cpu_percent()
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
                        
                self.memory_samples.append(memory_mb)
                self.cpu_samples.append(cpu_percent)
                
                time.sleep(0.1)  # Sample every 100ms
            except Exception:
                pass

class DockerManager:
    """Manage Docker operations for testing"""
    
    @staticmethod
    def build_image(dockerfile_path: str, tag: str) -> Tuple[bool, float, str]:
        """Build Docker image and return success, time, and output"""
        start_time = time.time()
        
        try:
            cmd = ["docker", "build", "-t", tag, "."]
            print(f"  🔧 Running: {' '.join(cmd)}")
            result = subprocess.run(cmd, cwd=dockerfile_path, capture_output=True, text=True, check=True)
            
            build_time = time.time() - start_time
            return True, build_time, result.stdout
            
        except subprocess.CalledProcessError as e:
            build_time = time.time() - start_time
            return False, build_time, e.stderr

class ImplementationTester:
    """Test a single implementation with comprehensive performance metrics"""
    
    def __init__(self, impl_path: str, metadata: Dict, timeout: int = 60, track: str = "v1", profile: str = "quick"):
        self.impl_path = Path(impl_path)
        self.metadata = metadata
        self.language = metadata.get("language", "unknown")
        self.timeout = timeout
        self.track = track
        self.profile = profile
        # Calculate reasonable timeouts for each phase based on main timeout
        self.clean_timeout = max(5, min(30, timeout // 4))
        self.analyze_timeout = max(10, min(timeout // 2, timeout - 10))
        self.build_timeout = max(10, min(timeout // 2, timeout - 10))
        self.docker_timeout = max(10, min(60, timeout // 2))
        self.results = {
            "language": self.language,
            "path": str(self.impl_path),
            "metadata": metadata,
            "track": track,
            "profile": profile,
            "timings": {},
            "memory": {},
            "size": {},
            "normalized": {},
            "docker": {},
            "task_results": {},
            "test_results": {},
            "errors": [],
            "status": "pending"
        }
        
    def run_full_test(self) -> Dict:
        """Run complete performance test suite"""
        print(f"\n{'='*60}")
        print(f"Testing {self.language} implementation")
        print(f"Path: {self.impl_path}")
        print(f"{'='*60}")
        
        try:
            # Phase 0: Collect source size metrics (for normalized comparisons)
            self._collect_code_size_metrics()

            # Phase 1: Clear Docker cache
            self._clear_cache()
            
            # Phase 2: Docker-based testing (replaces native build/test)
            print("🐳 Running all tests via Docker (ensures consistent environment)")
            self._run_docker_tests()

            # Post phase: compute normalized performance metrics
            self._compute_normalized_metrics()
            
            self.results["status"] = "completed"
            
        except Exception as e:
            self.results["errors"].append(f"Test failed: {str(e)}")
            self.results["status"] = "failed"
            
        return self.results

    def _collect_code_size_metrics(self):
        """Collect normalized source LOC/file metrics."""
        try:
            size_metrics = collect_metrics_for_impl(self.impl_path)
            self.results["size"] = {
                "source_loc": size_metrics.get("source_loc", 0),
                "source_files": size_metrics.get("source_files", 0),
            }
            print(
                "📏 Source size: "
                f"{self.results['size']['source_loc']} LOC across "
                f"{self.results['size']['source_files']} files"
            )
        except Exception as e:
            self.results["errors"].append(f"Code size metrics error: {str(e)}")
            self.results["size"] = {"source_loc": 0, "source_files": 0}

    def _compute_normalized_metrics(self):
        """Compute normalized metrics (ms/KLOC)."""
        source_loc = self.results.get("size", {}).get("source_loc", 0)
        if source_loc <= 0:
            return

        kloc = source_loc / 1000.0
        timings = self.results.get("timings", {})

        build_s = timings.get("build_seconds", 0) or 0
        analyze_s = timings.get("analyze_seconds", 0) or 0
        runtime_s = timings.get("test_seconds", 0) or 0

        self.results["normalized"] = {
            "build_ms_per_kloc": (build_s * 1000.0) / kloc,
            "analyze_ms_per_kloc": (analyze_s * 1000.0) / kloc,
            "runtime_ms_per_kloc": (runtime_s * 1000.0) / kloc,
        }
    
    def _clear_cache(self):
        """Clear build cache"""
        print("🧹 Clearing build cache...")
        
        # Clear local build artifacts using make clean
        if (self.impl_path / "Makefile").exists():
            try:
                cmd = ["make", "clean"]
                print(f"🔧 Running: {' '.join(cmd)}")
                result = subprocess.run(
                    cmd, 
                    cwd=self.impl_path, 
                    capture_output=True, 
                    text=True,
                    timeout=self.clean_timeout
                )
                
                if result.returncode == 0:
                    print("✅ Local cache cleared with make clean")
                else:
                    print(f"⚠️  make clean returned non-zero exit code: {result.stderr[:200]}")
                    
            except subprocess.TimeoutExpired:
                print("⚠️  make clean timeout")
            except Exception as e:
                print(f"⚠️  make clean error: {str(e)}")
        else:
            print("⚠️  No Makefile found, skipping cache clearing")
        
        print("✅ Cache clearing completed")
    
    def _run_analyze(self):
        """Run static analysis with timing"""
        print("🔍 Running static analysis...")
        
        monitor = PerformanceMonitor()
        monitor.start_monitoring()
        
        start_time = time.time()
        
        try:
            if (self.impl_path / "Makefile").exists():
                cmd = ["make", "analyze"]
                print(f"🔧 Running: {' '.join(cmd)}")
                result = subprocess.run(
                    cmd, 
                    cwd=self.impl_path, 
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=self.analyze_timeout
                )
                
                analysis_time = time.time() - start_time
                memory_stats = monitor.stop_monitoring()
                
                self.results["timings"]["analyze_seconds"] = analysis_time
                self.results["memory"]["analyze"] = memory_stats
                
                print(f"✅ Analysis completed in {analysis_time:.2f}s")
                
                if result.returncode != 0:
                    self.results["errors"].append(f"Analysis warnings: {result.stderr[:500]}")
            else:
                print("⚠️  No Makefile found, skipping analysis")
                
        except subprocess.TimeoutExpired:
            monitor.stop_monitoring()
            self.results["errors"].append(f"Analysis timeout ({self.analyze_timeout}s)")
        except Exception as e:
            monitor.stop_monitoring()
            self.results["errors"].append(f"Analysis error: {str(e)}")
    
    def _run_build(self):
        """Run build with timing"""
        print("🔨 Building implementation...")
        
        monitor = PerformanceMonitor()
        monitor.start_monitoring()
        
        start_time = time.time()
        build_success = False
        
        try:
            if (self.impl_path / "Makefile").exists():
                cmd = ["make", "build"]
                print(f"🔧 Running: {' '.join(cmd)}")
                result = subprocess.run(
                    cmd, 
                    cwd=self.impl_path, 
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=self.build_timeout
                )
                
                build_time = time.time() - start_time
                memory_stats = monitor.stop_monitoring()
                
                self.results["timings"]["build_seconds"] = build_time
                self.results["memory"]["build"] = memory_stats
                
                if result.returncode == 0:
                    print(f"✅ Build completed in {build_time:.2f}s")
                    build_success = True
                else:
                    print(f"❌ Build failed in {build_time:.2f}s")
                    self.results["errors"].append(f"Build failed: {result.stderr[:500]}")
                    raise Exception(f"Build failed with exit code {result.returncode}")
            else:
                # Try direct build command from metadata
                build_cmd = self.metadata.get("build", "")
                if build_cmd:
                    cmd = build_cmd.split()
                    print(f"🔧 Running: {' '.join(cmd)}")
                    result = subprocess.run(
                        cmd, 
                        cwd=self.impl_path, 
                        stderr=subprocess.PIPE,
                        text=True,
                        timeout=self.build_timeout
                    )
                    
                    build_time = time.time() - start_time
                    memory_stats = monitor.stop_monitoring()
                    
                    self.results["timings"]["build_seconds"] = build_time
                    self.results["memory"]["build"] = memory_stats
                    
                    if result.returncode == 0:
                        print(f"✅ Build completed in {build_time:.2f}s")
                        build_success = True
                    else:
                        print(f"❌ Build failed in {build_time:.2f}s")
                        self.results["errors"].append(f"Build failed: {result.stderr[:500]}")
                        raise Exception(f"Build failed with exit code {result.returncode}")
                else:
                    print("⚠️  No build command found")
                    raise Exception("No build command found")
                    
        except subprocess.TimeoutExpired:
            monitor.stop_monitoring()
            self.results["errors"].append(f"Build timeout ({self.build_timeout}s)")
            raise Exception("Build timeout")
        except Exception as e:
            monitor.stop_monitoring()
            if "Build failed" not in str(e) and "Build timeout" not in str(e) and "No build command" not in str(e):
                self.results["errors"].append(f"Build error: {str(e)}")
            raise
    
    def _run_chess_tests(self):
        """Run chess client tests using existing test harness"""
        print("♟️  Running chess client tests...")
        
        monitor = PerformanceMonitor()
        monitor.start_monitoring()
        
        start_time = time.time()
        # Calculate reasonable timeout for chess tests (remaining time from main timeout)
        chess_test_timeout = max(15, self.timeout // 3)  # At least 15s, up to 1/3 of main timeout
        
        try:
            # Use existing test harness
            tester = ChessEngineTester(str(self.impl_path), self.metadata)
            suite = TestSuite()
            
            if tester.start():
                # Calculate shorter timeout per test based on available time
                per_test_timeout = max(2, min(5, chess_test_timeout // len([t for t in suite.tests if not t.get("optional")])))
                
                # Run all non-optional tests with overall timeout
                for test in suite.tests:
                    if test.get("optional"):
                        continue
                    
                    # Check if we've exceeded the chess test timeout
                    elapsed = time.time() - start_time
                    if elapsed > chess_test_timeout:
                        print(f"  ⏰ Chess tests timed out after {elapsed:.1f}s (limit: {chess_test_timeout}s)")
                        self.results["errors"].append(f"Chess tests timeout ({chess_test_timeout}s)")
                        break
                    
                    # Override test timeout to fit within our budget
                    test_copy = test.copy()
                    test_copy["timeout"] = per_test_timeout
                    
                    success = suite.run_test(tester, test_copy)
                    print(f"  {'✅' if success else '❌'} {test['name']} ({per_test_timeout}s timeout)")
                
                tester.stop()
                
                test_time = time.time() - start_time
                memory_stats = monitor.stop_monitoring()
                
                self.results["timings"]["test_seconds"] = test_time
                self.results["memory"]["test"] = memory_stats
                self.results["test_results"] = tester.results
                
                passed = len(tester.results["passed"])
                failed = len(tester.results["failed"])
                
                print(f"✅ Tests completed in {test_time:.2f}s ({passed} passed, {failed} failed)")
                
            else:
                monitor.stop_monitoring()
                self.results["errors"].append("Failed to start chess engine")
                
        except Exception as e:
            monitor.stop_monitoring()
            self.results["errors"].append(f"Chess test error: {str(e)}")
    
    def _run_docker_tests(self):
        """Run benchmark tasks via Docker plus shared harness."""
        print("🐳 Running comprehensive Docker-based tests...")
        
        if not (self.impl_path / "Dockerfile").exists():
            print("⚠️  No Dockerfile found, skipping Docker tests")
            self.results["errors"].append("No Dockerfile found")
            return
            
        image_name = f"chess-{self.language.lower()}"
        
        # Phase 1: Build Docker image (prerequisite for task execution)
        print("  🔨 Building Docker image (prerequisite)...")
        monitor = PerformanceMonitor()
        monitor.start_monitoring()
        success, build_time, output = DockerManager.build_image(
            str(self.impl_path), 
            image_name
        )
        memory_stats = monitor.stop_monitoring()

        if "memory" not in self.results:
            self.results["memory"] = {}
        self.results["memory"]["image"] = memory_stats

        self.results["timings"]["image_build_seconds"] = build_time
        self.results["docker"]["build_time"] = build_time
        self.results["docker"]["build_success"] = success
        self.results["docker"]["image_build_time"] = build_time
        self.results["docker"]["image_build_success"] = success

        # Default task outcomes for reporting consistency
        self.results["task_results"] = {
            "make_build": False,
            "make_analyze": False,
            "make_test": False,
            "make_test_chess_engine": False,
        }

        if success:
            print(f"  ✅ Docker build completed in {build_time:.2f}s")

            # Phase 2: make build
            print("  🔧 Running task: make build")
            make_build_success, make_build_time = self._run_docker_command(
                image_name,
                "make build",
                phase="build",
            )
            self.results["timings"]["build_seconds"] = make_build_time
            self.results["docker"]["make_build_time"] = make_build_time
            self.results["docker"]["make_build_success"] = make_build_success
            self.results["task_results"]["make_build"] = make_build_success

            # Phase 3: make analyze
            print("  🔧 Running task: make analyze")
            analyze_success, analyze_time = self._run_docker_command(
                image_name,
                "make analyze",
                phase="analyze",
            )
            self.results["timings"]["analyze_seconds"] = analyze_time
            self.results["docker"]["make_analyze_time"] = analyze_time
            self.results["docker"]["make_analyze_success"] = analyze_success
            self.results["task_results"]["make_analyze"] = analyze_success

            # Phase 4: make test
            print("  🔧 Running task: make test")
            test_success, test_time = self._run_docker_command(
                image_name,
                "make test",
                phase="test",
            )
            self.results["timings"]["test_seconds"] = test_time
            self.results["timings"]["test_internal_seconds"] = test_time
            self.results["docker"]["test_time"] = test_time
            self.results["docker"]["test_success"] = test_success
            self.results["docker"]["make_test_time"] = test_time
            self.results["docker"]["make_test_success"] = test_success
            self.results["task_results"]["make_test"] = test_success

            # Phase 5: make test-chess-engine equivalent via shared harness
            print(f"  🔧 Running task: make test-chess-engine (track={self.track})")
            track_test_success, track_test_time = self._run_track_suite(image_name, self.track)
            self.results["timings"]["test_chess_engine_seconds"] = track_test_time
            self.results["timings"][f"test_{self.track.replace('-', '_')}_seconds"] = track_test_time
            self.results["docker"]["test_chess_engine_time"] = track_test_time
            self.results["docker"]["test_chess_engine_success"] = track_test_success
            self.results["docker"]["track_test_time"] = track_test_time
            self.results["docker"]["track_test_success"] = track_test_success
            self.results["task_results"]["make_test_chess_engine"] = track_test_success

            # Overall success if all benchmark tasks passed
            overall_success = (
                success
                and make_build_success
                and analyze_success
                and test_success
                and track_test_success
            )
            if overall_success:
                print(
                    "  ✅ All Docker tests passed "
                    f"(image: {build_time:.1f}s, make build: {make_build_time:.1f}s, "
                    f"make analyze: {analyze_time:.1f}s, make test: {test_time:.1f}s, "
                    f"make test-chess-engine: {track_test_time:.1f}s)"
                )
                # Set traditional result fields for compatibility
                self.results["test_results"]["passed"] = [
                    "make_build",
                    "make_analyze",
                    "make_test",
                    "make_test_chess_engine",
                ]
                self.results["test_results"]["failed"] = []
            else:
                failed_phases = []
                if not success:
                    failed_phases.append("image")
                if not make_build_success:
                    failed_phases.append("make_build")
                if not analyze_success:
                    failed_phases.append("make_analyze")
                if not test_success:
                    failed_phases.append("make_test")
                if not track_test_success:
                    failed_phases.append("make_test_chess_engine")
                print(f"  ❌ Docker tests failed in phases: {', '.join(failed_phases)}")
                self.results["test_results"]["passed"] = []
                self.results["test_results"]["failed"] = failed_phases
                
        else:
            print(f"  ❌ Docker build failed in {build_time:.2f}s")
            self.results["errors"].append(f"Docker build failed: {output[:500]}")
            self.results["test_results"]["passed"] = []
            self.results["test_results"]["failed"] = ["image"]

    def _run_docker_command(
        self,
        image_name: str,
        command: str,
        phase: str = "test",
        timeout_seconds: Optional[int] = None,
    ) -> Tuple[bool, float]:
        """Run a command inside a Docker container and return (success, time)."""
        # We wrap the command to capture the peak memory from cgroups
        # This works on both cgroup v1 and v2 environments inside Docker
        wrapped_command = f"{command}; PEAK=$(cat /sys/fs/cgroup/memory.peak 2>/dev/null || cat /sys/fs/cgroup/memory/memory.max_usage_in_bytes 2>/dev/null || echo 0); echo \"---MEMORY_PEAK_BYTES: $PEAK---\""
        
        try:
            start_time = time.time()
            cmd = ["docker", "run", "--rm", image_name, "sh", "-c", wrapped_command]
            print(f"    🔧 Running: {command}")
            effective_timeout = timeout_seconds if timeout_seconds is not None else max(10, self.docker_timeout // 2)
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=effective_timeout)
            elapsed = time.time() - start_time
            
            # Parse memory peak from output
            memory_mb = 0
            if result.stdout:
                match = re.search(r"---MEMORY_PEAK_BYTES: (\d+)---", result.stdout)
                if match:
                    peak_bytes = int(match.group(1))
                    memory_mb = peak_bytes / (1024 * 1024)
            
            # Store memory stats in results
            if "memory" not in self.results:
                self.results["memory"] = {}
            
            # Use a dictionary compatible with the expected format
            self.results["memory"][phase] = {
                "memory_mb": memory_mb,
                "peak_memory_mb": memory_mb,
                "avg_cpu_percent": 0,
                "psutil_available": PSUTIL_AVAILABLE,
                "source": "cgroup"
            }
            
            success = result.returncode == 0
            if not success:
                self.results["errors"].append(f"{command} failed: {result.stderr[:200]}")
            
            return success, elapsed
            
        except subprocess.TimeoutExpired:
            elapsed = time.time() - start_time
            self.results["errors"].append(f"{command} timeout after {elapsed:.1f}s")
            return False, elapsed
        except Exception as e:
            elapsed = time.time() - start_time
            self.results["errors"].append(f"{command} error: {str(e)}")
            return False, elapsed

    def _run_track_suite(self, image_name: str, track: str) -> Tuple[bool, float]:
        """Run shared track suite through test_harness using the Docker image."""
        if track not in TRACK_TO_SUITE:
            self.results["errors"].append(f"Unknown track: {track}")
            return False, 0.0

        start_time = time.time()
        timeout = 180 if self.profile == "quick" else 600

        cmd = [
            "python3",
            "test/test_harness.py",
            "--impl",
            str(self.impl_path),
            "--track",
            track,
            "--docker-image",
            image_name,
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
            elapsed = time.time() - start_time

            if result.returncode != 0:
                snippet = (result.stdout + "\n" + result.stderr)[:500]
                self.results["errors"].append(f"track {track} suite failed: {snippet}")
                return False, elapsed

            return True, elapsed
        except subprocess.TimeoutExpired:
            elapsed = time.time() - start_time
            self.results["errors"].append(f"track {track} suite timeout after {elapsed:.1f}s")
            return False, elapsed
        except Exception as e:
            elapsed = time.time() - start_time
            self.results["errors"].append(f"track {track} suite error: {str(e)}")
            return False, elapsed

def generate_performance_report(results: List[Dict]) -> str:
    """Generate comprehensive performance report"""
    report = []
    report.append("=" * 80)
    report.append("CHESS ENGINE PERFORMANCE TEST REPORT")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("=" * 80)
    report.append("")
    
    # Summary table
    report.append("PERFORMANCE SUMMARY")
    report.append("-" * 118)
    report.append(
        f"{'Language':<12} {'Status':<10} {'LOC':<8} "
        f"{'Build':<9} {'Analyze':<9} {'Test':<9} {'Test-CE':<10} "
        f"{'Memory':<10} {'Tasks':<8}"
    )
    report.append("-" * 118)
    
    for result in sorted(results, key=lambda x: x.get("language", "")):
        lang = result.get("language", "Unknown")[:11]
        status = result.get("status", "unknown")[:9]
        
        build_time = result.get("timings", {}).get("build_seconds", 0)
        analyze_time = result.get("timings", {}).get("analyze_seconds", 0)
        test_time = result.get("timings", {}).get("test_seconds", 0)
        test_chess_engine_time = result.get("timings", {}).get("test_chess_engine_seconds", 0)
        source_loc = result.get("size", {}).get("source_loc", 0)
        
        peak_memory = max([
            result.get("memory", {}).get("analyze", {}).get("peak_memory_mb", 0),
            result.get("memory", {}).get("build", {}).get("peak_memory_mb", 0),
            result.get("memory", {}).get("test", {}).get("peak_memory_mb", 0),
            result.get("memory", {}).get("image", {}).get("peak_memory_mb", 0)
        ])

        task_results = result.get("task_results", {})
        task_order = [
            "make_build",
            "make_analyze",
            "make_test",
            "make_test_chess_engine",
        ]
        passed = sum(1 for key in task_order if task_results.get(key) is True)
        total = len(task_order)

        report.append(
            f"{lang:<12} {status:<10} "
            f"{source_loc:<8} "
            f"{build_time:>7.1f}s {analyze_time:>7.1f}s {test_time:>7.1f}s {test_chess_engine_time:>8.1f}s "
            f"{peak_memory:>8.0f}MB {passed}/{total:<6}"
        )
    
    # Detailed results
    for result in results:
        report.append(f"\n{'=' * 60}")
        report.append(f"DETAILED RESULTS: {result.get('language', 'Unknown').upper()}")
        report.append(f"{'=' * 60}")
        
        # Timing breakdown
        timings = result.get("timings", {})
        if timings:
            report.append("\nTIMING BREAKDOWN:")
            for phase, time_val in timings.items():
                report.append(f"  {phase.replace('_', ' ').title()}: {time_val:.2f}s")

        # Source size and normalized metrics
        size = result.get("size", {})
        normalized = result.get("normalized", {})
        if size:
            report.append("\nSOURCE SIZE:")
            report.append(
                f"  Source LOC: {size.get('source_loc', 0)} "
                f"(files: {size.get('source_files', 0)})"
            )
        if normalized:
            report.append("\nNORMALIZED METRICS:")
            report.append(f"  Build: {normalized.get('build_ms_per_kloc', 0):.2f} ms/KLOC")
            report.append(f"  Analyze: {normalized.get('analyze_ms_per_kloc', 0):.2f} ms/KLOC")
            report.append(f"  Runtime: {normalized.get('runtime_ms_per_kloc', 0):.2f} ms/KLOC")
        
        # Memory usage
        memory = result.get("memory", {})
        if memory:
            report.append("\nMEMORY USAGE:")
            for phase, mem_data in memory.items():
                if isinstance(mem_data, dict):
                    peak = mem_data.get("peak_memory_mb", 0)
                    avg = mem_data.get("avg_memory_mb", 0)
                    report.append(f"  {phase.title()}: Peak {peak:.1f}MB, Avg {avg:.1f}MB")
        
        # Test results
        test_results = result.get("test_results", {})
        if test_results:
            passed = test_results.get("passed", [])
            failed = test_results.get("failed", [])
            
            report.append(f"\nCHESS ENGINE TESTS: {len(passed)} passed, {len(failed)} failed")
            
            if failed:
                report.append("  Failed tests:")
                for failure in failed:
                    if isinstance(failure, dict):
                        test_name = failure.get("test", "Unknown")
                    else:
                        test_name = str(failure)
                    report.append(f"    ❌ {test_name}")
        
        # Docker results
        docker = result.get("docker", {})
        if docker:
            report.append(f"\nDOCKER TESTS:")
            image_build_success = docker.get("image_build_success", docker.get("build_success", False))
            image_build_time = docker.get("image_build_time", docker.get("build_time", 0))
            make_build_success = docker.get("make_build_success", False)
            make_build_time = docker.get("make_build_time", 0)
            make_analyze_success = docker.get("make_analyze_success", False)
            make_analyze_time = docker.get("make_analyze_time", 0)
            make_test_success = docker.get("make_test_success", docker.get("test_success", False))
            make_test_time = docker.get("make_test_time", docker.get("test_time", 0))
            make_test_chess_success = docker.get("test_chess_engine_success", docker.get("track_test_success", False))
            make_test_chess_time = docker.get("test_chess_engine_time", docker.get("track_test_time", 0))

            report.append(f"  Image build: {'✅' if image_build_success else '❌'} ({image_build_time:.2f}s)")
            report.append(f"  make build: {'✅' if make_build_success else '❌'} ({make_build_time:.2f}s)")
            report.append(f"  make analyze: {'✅' if make_analyze_success else '❌'} ({make_analyze_time:.2f}s)")
            report.append(f"  make test: {'✅' if make_test_success else '❌'} ({make_test_time:.2f}s)")
            report.append(
                "  make test-chess-engine "
                f"(track={result.get('track', 'v1')}): "
                f"{'✅' if make_test_chess_success else '❌'} "
                f"({make_test_chess_time:.2f}s)"
            )
        
        # Errors
        errors = result.get("errors", [])
        if errors:
            report.append("\nERRORS:")
            for error in errors[:5]:  # Limit to first 5 errors
                report.append(f"  ❌ {error}")
            if len(errors) > 5:
                report.append(f"  ... and {len(errors) - 5} more errors")
    
    report.append("\n" + "=" * 80)
    return "\n".join(report)

def main():
    """Main performance testing function"""
    parser = argparse.ArgumentParser(
        description="Chess Engine Performance Testing Suite",
        epilog="""
Examples:
  python3 performance_test.py
    Test all implementations in implementations/ directory
    
  python3 performance_test.py --impl implementations/rust
    Test only the Rust implementation
    
  python3 performance_test.py --output report.txt --json data.json
    Save detailed text report and JSON data to files
    
  python3 performance_test.py --timeout 3600
    Set 1 hour timeout for testing (useful for slow builds)

Test Phases (All Docker-based):
  1. Cache Clearing   - Clears local build artifacts  
  2. Docker Build     - Builds implementation container (prerequisite)
  3. Build Task       - Runs 'make build' inside container
  4. Static Analysis  - Runs 'make analyze' inside container
  5. Internal Tests   - Runs 'make test' inside container
  6. Shared Suite     - Runs 'make test-chess-engine' equivalent for selected track

Performance Metrics:
  - Timing: Docker image + make build/analyze/test/test-chess-engine measurements
  - Memory: Peak and average memory usage (requires psutil)  
  - Chess Tests: Protocol compliance and correctness via containers
  - Container: Build and execution times for each implementation

Requirements:
  - Python 3.7+
  - psutil (optional, for memory monitoring)  
  - Docker (required for all testing)
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        "--impl", 
        metavar="PATH",
        help="Test specific implementation directory (e.g., implementations/rust)"
    )
    
    parser.add_argument(
        "--output", 
        metavar="FILE",
        help="Save detailed text report to file"
    )
    
    parser.add_argument(
        "--json", 
        metavar="FILE",
        help="Save machine-readable JSON results to file"
    )
    
    parser.add_argument(
        "--timeout", 
        type=int, 
        default=1800, 
        metavar="SECONDS",
        help="Overall timeout in seconds (default: 1800 = 30 minutes)"
    )

    parser.add_argument(
        "--track",
        default="v1",
        choices=sorted(TRACK_TO_SUITE.keys()),
        help="Track suite to run (default: v1)"
    )

    parser.add_argument(
        "--profile",
        default="quick",
        choices=["quick", "full"],
        help="Benchmark profile (quick or full)"
    )
    
    
    args = parser.parse_args()
    
    print("🚀 Chess Engine Performance Testing Suite")
    print("=" * 60)
    
    # Find implementations
    if args.impl:
        impl_path = Path(args.impl)
        metadata = get_metadata(str(impl_path))
        if metadata:
            implementations = [(str(impl_path), metadata)]
        else:
            print(f"❌ No metadata found in {args.impl} (check chess.meta or Dockerfile labels)")
            return 1
    else:
        base_dir = Path(__file__).parent.parent
        implementations = find_implementations(str(base_dir / "implementations"))
    
    if not implementations:
        print("❌ No implementations found!")
        return 1
    
    print(f"Found {len(implementations)} implementation(s) to test")
    
    # Test each implementation
    all_results = []
    start_time = time.time()
    
    for impl_path, metadata in implementations:
        tester = ImplementationTester(impl_path, metadata, args.timeout, args.track, args.profile)
        result = tester.run_full_test()
        all_results.append(result)
        
        # Check overall timeout
        if time.time() - start_time > args.timeout:
            print(f"\n⏰ Overall timeout reached ({args.timeout}s)")
            break
    
    # Generate reports
    text_report = generate_performance_report(all_results)
    print("\n" + text_report)
    
    # Save reports
    if args.output:
        with open(args.output, 'w') as f:
            f.write(text_report)
        print(f"\n📄 Text report saved to {args.output}")
    
    # Filter results: Only save JSON for completed benchmarks with valid timing data
    # This enforces benchmark output constraints at the CI level
    valid_results = []
    skipped_results = []
    
    for result in all_results:
        status = result.get("status")
        timings = result.get("timings", {})
        build_seconds = timings.get("build_seconds")
        test_seconds = timings.get("test_seconds")
        
        # Check if benchmark is complete and has valid timing data
        # Timing values must be non-None and non-negative
        has_valid_build = build_seconds is not None and build_seconds >= 0
        has_valid_test = test_seconds is not None and test_seconds >= 0
        
        if status == "completed" and has_valid_build and has_valid_test:
            valid_results.append(result)
        else:
            lang = result.get("language", "unknown")
            reason = []
            if status != "completed":
                reason.append(f"status={status}")
            # Only check timing data validity when status is completed
            if status == "completed":
                if build_seconds is None:
                    reason.append("missing build_seconds")
                elif build_seconds < 0:
                    reason.append("build_seconds is negative")
                if test_seconds is None:
                    reason.append("missing test_seconds")
                elif test_seconds < 0:
                    reason.append("test_seconds is negative")
            skipped_results.append((lang, ", ".join(reason)))
    
    if args.json:
        if valid_results:
            with open(args.json, 'w') as f:
                json.dump(valid_results, f, indent=2)
            print(f"📄 JSON results saved to {args.json} ({len(valid_results)} valid benchmark(s))")
        else:
            print(f"⚠️  No valid benchmarks to save to JSON")
        
        if skipped_results:
            print(f"\n⚠️  Skipped {len(skipped_results)} incomplete/failed benchmark(s):")
            for lang, reason in skipped_results:
                print(f"   - {lang}: {reason}")
    
    # Exit with error code if any tests failed
    failed_count = sum(1 for r in all_results if r.get("status") != "completed")
    if failed_count > 0:
        print(f"\n❌ {failed_count} implementation(s) failed testing")
        return 1
    else:
        print(f"\n✅ All {len(all_results)} implementation(s) completed successfully")
        return 0

if __name__ == "__main__":
    sys.exit(main())
