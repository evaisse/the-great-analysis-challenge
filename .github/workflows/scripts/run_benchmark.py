#!/usr/bin/env python3
"""
Run benchmark for a specific implementation or all implementations.
"""

import os
import subprocess
import json
from typing import List, Tuple


def discover_implementations() -> List[Tuple[str, str]]:
    """Discover all implementations."""
    implementations = []
    impl_dir = "implementations"
    
    if not os.path.exists(impl_dir):
        return implementations
    
    for name in os.listdir(impl_dir):
        impl_path = os.path.join(impl_dir, name)
        dockerfile_path = os.path.join(impl_path, "Dockerfile")
        
        if os.path.isdir(impl_path) and os.path.exists(dockerfile_path):
            implementations.append((name, impl_path))
    
    return sorted(implementations)


def run_benchmark(impl_name: str, impl_dir: str, timeout: int = 300) -> bool:
    """Run benchmark for a specific implementation."""
    print(f"🏁 Running benchmark for {impl_name}...")
    
    if not impl_name or not impl_dir:
        print("Error: Implementation name and directory required")
        return False
    
    # Create reports directory
    os.makedirs("benchmark_reports", exist_ok=True)
    
    # Run performance test
    cmd = [
        "python3", "test/performance_test.py",
        "--impl", impl_dir,
        "--timeout", str(timeout),
        "--output", f"benchmark_reports/performance_report_{impl_name}.txt",
        "--json", f"benchmark_reports/performance_data_{impl_name}.json"
    ]
    
    print(f"🔧 Running: {' '.join(cmd)}")
    
    try:
        with open(f"benchmark_reports/benchmark_output_{impl_name}.txt", "w") as output_file:
            result = subprocess.run(cmd, stdout=output_file, stderr=subprocess.STDOUT, timeout=timeout+60)
        
        if result.returncode == 0:
            print(f"✅ Benchmark completed for {impl_name}")
            return True
        else:
            print(f"❌ Benchmark failed for {impl_name} (exit code: {result.returncode})")
            return False
        
    except subprocess.TimeoutExpired:
        print(f"⏰ Benchmark timed out for {impl_name}")
        return False
    except Exception as e:
        print(f"❌ Benchmark failed for {impl_name}: {e}")
        return False


def run_all_benchmarks(timeout: int = 300) -> int:
    """Run benchmarks on all implementations."""
    implementations = discover_implementations()
    
    if not implementations:
        print("❌ No implementations found!")
        return 1
    
    print(f"🚀 Running benchmarks on {len(implementations)} implementations...")
    
    failed_count = 0
    for impl_name, impl_dir in implementations:
        success = run_benchmark(impl_name, impl_dir, timeout)
        if not success:
            failed_count += 1
    
    if failed_count > 0:
        print(f"\n❌ {failed_count} implementation(s) failed benchmarking")
        return 1
    else:
        print(f"\n✅ All {len(implementations)} implementation(s) completed successfully")
        return 0


def main(args):
    """Main function for run-benchmark command."""
    if args.all:
        return run_all_benchmarks(args.timeout)
    else:
        success = run_benchmark(args.impl_name, args.impl_dir, args.timeout)
        return 0 if success else 1


if __name__ == "__main__":
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description='Run benchmark for implementation')
    parser.add_argument('impl_name', nargs='?', help='Implementation name')
    parser.add_argument('impl_dir', nargs='?', help='Implementation directory')
    parser.add_argument('--timeout', type=int, default=300, help='Timeout in seconds')
    parser.add_argument('--all', action='store_true', help='Run benchmarks on all implementations')
    
    args = parser.parse_args()
    
    if args.all:
        if args.impl_name or args.impl_dir:
            print("ERROR: Cannot specify implementation when using --all")
            sys.exit(1)
    else:
        if not args.impl_name or not args.impl_dir:
            print("ERROR: Implementation name and directory required (or use --all)")
            parser.print_help()
            sys.exit(1)
    
    sys.exit(main(args))