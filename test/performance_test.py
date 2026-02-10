#!/usr/bin/env python3
"""
Chess Engine Performance Testing Script

This script runs comprehensive performance tests against chess engine implementations:
- Clears Docker build cache
- Measures analyze, build, and test timing
- Monitors memory consumption
- Uses existing test harness for consistent chess client testing
"""

import subprocess
import json
import time
import sys
import os
import threading
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
from test_harness import ChessEngineTester, TestSuite, find_implementations

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
    
    def __init__(self, impl_path: str, metadata: Dict, timeout: int = 60):
        self.impl_path = Path(impl_path)
        self.metadata = metadata
        self.language = metadata.get("language", "unknown")
        self.timeout = timeout
        # Calculate reasonable timeouts for each phase based on main timeout
        self.clean_timeout = max(5, min(30, timeout // 4))
        self.analyze_timeout = max(10, min(timeout // 2, timeout - 10))
        self.build_timeout = max(10, min(timeout // 2, timeout - 10))
        self.docker_timeout = max(10, min(60, timeout // 2))
        self.results = {
            "language": self.language,
            "path": str(self.impl_path),
            "metadata": metadata,
            "timings": {},
            "memory": {},
            "docker": {},
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
            # Phase 1: Clear Docker cache
            self._clear_cache()
            
            # Phase 2: Docker-based testing (replaces native build/test)
            print("🐳 Running all tests via Docker (ensures consistent environment)")
            self._run_docker_tests()
            
            self.results["status"] = "completed"
            
        except Exception as e:
            self.results["errors"].append(f"Test failed: {str(e)}")
            self.results["status"] = "failed"
            
        return self.results
    
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
        """Run all tests via Docker (build, analyze, test)"""
        print("🐳 Running comprehensive Docker-based tests...")
        
        if not (self.impl_path / "Dockerfile").exists():
            print("⚠️  No Dockerfile found, skipping Docker tests")
            self.results["errors"].append("No Dockerfile found")
            return
            
        image_name = f"chess-{self.language.lower()}"
        
        # Phase 1: Build Docker image (includes dependency installation and compilation)
        print("  🔨 Building Docker image (includes analysis and build)...")
        success, build_time, output = DockerManager.build_image(
            str(self.impl_path), 
            image_name
        )
        
        self.results["timings"]["build_seconds"] = build_time
        self.results["docker"]["build_time"] = build_time
        self.results["docker"]["build_success"] = success
        
        if success:
            print(f"  ✅ Docker build completed in {build_time:.2f}s")
            
            # Phase 2: Run analysis inside container  
            print("  🔍 Running static analysis...")
            analyze_success, analyze_time = self._run_docker_command(image_name, "make analyze")
            self.results["timings"]["analyze_seconds"] = analyze_time
            
            # Phase 3: Run tests inside container
            print("  ♟️  Running chess engine tests...")
            test_success, test_time = self._run_docker_command(image_name, "make test")
            self.results["timings"]["test_seconds"] = test_time
            self.results["docker"]["test_time"] = test_time
            self.results["docker"]["test_success"] = test_success
            
            # Overall success if all phases passed
            overall_success = success and analyze_success and test_success
            if overall_success:
                print(f"  ✅ All Docker tests passed (build: {build_time:.1f}s, analyze: {analyze_time:.1f}s, test: {test_time:.1f}s)")
                # Set traditional result fields for compatibility
                self.results["test_results"]["passed"] = ["docker_build", "docker_analyze", "docker_test"]
                self.results["test_results"]["failed"] = []
            else:
                failed_phases = []
                if not success: failed_phases.append("build") 
                if not analyze_success: failed_phases.append("analyze")
                if not test_success: failed_phases.append("test")
                print(f"  ❌ Docker tests failed in phases: {', '.join(failed_phases)}")
                self.results["test_results"]["passed"] = []
                self.results["test_results"]["failed"] = failed_phases
                
        else:
            print(f"  ❌ Docker build failed in {build_time:.2f}s")
            self.results["errors"].append(f"Docker build failed: {output[:500]}")
            self.results["test_results"]["passed"] = []
            self.results["test_results"]["failed"] = ["docker_build"]
    
    def _run_docker_command(self, image_name: str, command: str) -> Tuple[bool, float]:
        """Run a command inside a Docker container and return (success, time)"""
        try:
            start_time = time.time()
            cmd = ["docker", "run", "--rm", image_name, "sh", "-c", command]
            print(f"    🔧 Running: {command}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=self.docker_timeout//2)
            elapsed = time.time() - start_time
            
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
    report.append("-" * 80)
    report.append(f"{'Language':<12} {'Status':<10} {'Analyze':<8} {'Build':<8} {'Test':<8} {'Memory':<10} {'Tests':<8}")
    report.append("-" * 80)
    
    for result in sorted(results, key=lambda x: x.get("language", "")):
        lang = result.get("language", "Unknown")[:11]
        status = result.get("status", "unknown")[:9]
        
        analyze_time = result.get("timings", {}).get("analyze_seconds", 0)
        build_time = result.get("timings", {}).get("build_seconds", 0)
        test_time = result.get("timings", {}).get("test_seconds", 0)
        
        peak_memory = max([
            result.get("memory", {}).get("analyze", {}).get("peak_memory_mb", 0),
            result.get("memory", {}).get("build", {}).get("peak_memory_mb", 0),
            result.get("memory", {}).get("test", {}).get("peak_memory_mb", 0)
        ])
        
        test_results = result.get("test_results", {})
        passed = len(test_results.get("passed", []))
        failed = len(test_results.get("failed", []))
        
        report.append(
            f"{lang:<12} {status:<10} "
            f"{analyze_time:>7.1f}s {build_time:>7.1f}s {test_time:>7.1f}s "
            f"{peak_memory:>8.0f}MB {passed}/{passed+failed:<6}"
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
            build_success = docker.get("build_success", False)
            build_time = docker.get("build_time", 0)
            test_success = docker.get("test_success", False)
            test_time = docker.get("test_time", 0)
            
            report.append(f"  Build: {'✅' if build_success else '❌'} ({build_time:.2f}s)")
            report.append(f"  Test: {'✅' if test_success else '❌'} ({test_time:.2f}s)")
        
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
  2. Docker Build     - Builds implementation container (includes dependencies and compilation)
  3. Static Analysis  - Runs 'make analyze' inside container
  4. Chess Testing    - Runs 'make test' inside container for protocol compliance

Performance Metrics:
  - Timing: Docker build, analysis, and test phase measurements
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
        tester = ImplementationTester(impl_path, metadata, args.timeout)
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