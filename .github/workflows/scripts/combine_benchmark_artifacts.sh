#!/bin/bash
# Combine benchmark artifacts from multiple jobs
# Usage: combine_benchmark_artifacts.sh

set -e

echo "=== Combining Benchmark Results ==="

# Create combined reports directory
mkdir -p benchmark_reports

# Copy all individual reports
find benchmark_artifacts/ -name "*.txt" -exec cp {} benchmark_reports/ \; 2>/dev/null || true
find benchmark_artifacts/ -name "*.json" -exec cp {} benchmark_reports/ \; 2>/dev/null || true

# Combine JSON reports using existing script
python3 .github/workflows/scripts/combine_benchmark_results.py

echo "✅ Benchmark results combined"