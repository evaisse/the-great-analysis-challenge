#!/bin/bash
# Run benchmark for a specific implementation
# Usage: run_benchmark.sh <implementation_name> <implementation_directory>

set -e

IMPL_NAME="$1"
IMPL_DIR="$2"

if [[ -z "$IMPL_NAME" || -z "$IMPL_DIR" ]]; then
    echo "Error: Implementation name and directory required"
    exit 1
fi

echo "🏁 Running benchmark for $IMPL_NAME..."

# Create reports directory
mkdir -p benchmark_reports

# Run performance test for this specific implementation
python3 test/performance_test.py \
    --impl "$IMPL_DIR" \
    --timeout 900 \
    --output "benchmark_reports/performance_report_$IMPL_NAME.txt" \
    --json "benchmark_reports/performance_data_$IMPL_NAME.json" \
    > "benchmark_reports/benchmark_output_$IMPL_NAME.txt" 2>&1 || true

echo "✅ Benchmark completed for $IMPL_NAME"