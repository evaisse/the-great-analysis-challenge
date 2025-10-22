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
    
    def __init__(self, impl_path: str, metadata: Dict):
        self.impl_path = Path(impl_path)
        self.metadata = metadata
        self.language = metadata.get("language", "unknown")
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
            
            # Phase 2: Run analyze
            self._run_analyze()
            
            # Phase 3: Build implementation
            self._run_build()
            
            # Phase 4: Run chess client tests
            self._run_chess_tests()
            
            # Phase 5: Docker tests
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
                    timeout=30
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
                    capture_output=True, 
                    text=True,
                    timeout=300  # 5 minute timeout
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
            self.results["errors"].append("Analysis timeout (5 minutes)")
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
                    capture_output=True, 
                    text=True,
                    timeout=600  # 10 minute timeout
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
                        capture_output=True, 
                        text=True,
                        timeout=600
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
            self.results["errors"].append("Build timeout (10 minutes)")
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
        
        try:
            # Use existing test harness
            tester = ChessEngineTester(str(self.impl_path), self.metadata)
            suite = TestSuite()
            
            if tester.start():
                # Run all non-optional tests
                for test in suite.tests:
                    if test.get("optional"):
                        continue
                        
                    success = suite.run_test(tester, test)
                    print(f"  {'✅' if success else '❌'} {test['name']}")
                
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
        """Run Docker build and test"""
        print("🐳 Running Docker tests...")
        
        if not (self.impl_path / "Dockerfile").exists():
            print("⚠️  No Dockerfile found, skipping Docker tests")
            return
            
        image_name = f"chess-{self.language.lower()}"
        
        # Build Docker image
        print("  Building Docker image...")
        success, build_time, output = DockerManager.build_image(
            str(self.impl_path), 
            image_name
        )
        
        self.results["docker"]["build_time"] = build_time
        self.results["docker"]["build_success"] = success
        
        if success:
            print(f"  ✅ Docker build completed in {build_time:.2f}s")
            
            # Test Docker image
            try:
                test_start = time.time()
                cmd = [
                    "docker", "run", "--rm", "-i", image_name,
                    "sh", "-c", "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | timeout 30s make test"
                ]
                print(f"  🔧 Running: {' '.join(cmd)}")
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
                
                docker_test_time = time.time() - test_start
                self.results["docker"]["test_time"] = docker_test_time
                self.results["docker"]["test_success"] = result.returncode == 0
                
                if result.returncode == 0:
                    print(f"  ✅ Docker test completed in {docker_test_time:.2f}s")
                else:
                    print(f"  ❌ Docker test failed in {docker_test_time:.2f}s")
                    self.results["errors"].append(f"Docker test failed: {result.stderr[:300]}")
                    
            except subprocess.TimeoutExpired:
                self.results["errors"].append("Docker test timeout")
            except Exception as e:
                self.results["errors"].append(f"Docker test error: {str(e)}")
        else:
            print(f"  ❌ Docker build failed in {build_time:.2f}s")
            self.results["errors"].append(f"Docker build failed: {output[:500]}")

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
                    test_name = failure.get("test", "Unknown")
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

Test Phases:
  1. Cache Clearing   - Runs 'make clean' to clear build artifacts
  2. Static Analysis  - Runs 'make analyze' with timing measurement
  3. Build Phase      - Runs 'make build' with timing measurement  
  4. Chess Testing    - Tests chess protocol compliance
  5. Docker Testing   - Builds and tests Docker containers

Performance Metrics:
  - Timing: Separate measurements for each phase
  - Memory: Peak and average memory usage (requires psutil)
  - Chess Tests: Protocol compliance and correctness
  - Docker: Container build and execution times

Requirements:
  - Python 3.7+
  - psutil (optional, for memory monitoring)
  - Docker (for container testing)
  - Each implementation's build tools
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
        meta_path = impl_path / "chess.meta"
        if meta_path.exists():
            with open(meta_path, 'r') as f:
                implementations = [(str(impl_path), json.load(f))]
        else:
            print(f"❌ No chess.meta found in {args.impl}")
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
        tester = ImplementationTester(impl_path, metadata)
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
    
    if args.json:
        with open(args.json, 'w') as f:
            json.dump(all_results, f, indent=2)
        print(f"📄 JSON results saved to {args.json}")
    
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