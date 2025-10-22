#!/usr/bin/env python3
"""
Run benchmark for a specific implementation.
"""

import os
import subprocess


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
    
    try:
        with open(f"benchmark_reports/benchmark_output_{impl_name}.txt", "w") as output_file:
            result = subprocess.run(cmd, stdout=output_file, stderr=subprocess.STDOUT, timeout=timeout+60)
        
        print(f"✅ Benchmark completed for {impl_name}")
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print(f"⏰ Benchmark timed out for {impl_name}")
        return False
    except Exception as e:
        print(f"❌ Benchmark failed for {impl_name}: {e}")
        return False


def main(args):
    """Main function for run-benchmark command."""
    success = run_benchmark(args.impl_name, args.impl_dir, args.timeout)
    return 0 if success else 1


if __name__ == "__main__":
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description='Run benchmark for implementation')
    parser.add_argument('impl_name', help='Implementation name')
    parser.add_argument('impl_dir', help='Implementation directory')
    parser.add_argument('--timeout', type=int, default=300, help='Timeout in seconds')
    
    args = parser.parse_args()
    sys.exit(main(args))