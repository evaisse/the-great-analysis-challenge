#!/bin/bash

set -euo pipefail

echo "🧪 Testing benchmark workflow components locally"
echo "==============================================="

if [[ ! -f "workflow" ]]; then
    echo "❌ Must be run from project root"
    exit 1
fi

mkdir -p .github/test-output
cd .github/test-output

echo ""
echo "1️⃣ Structure verification"
echo "-------------------------"
VERIFY_EXIT=0
../../workflow verify-implementations > verification_results.txt 2>&1 || VERIFY_EXIT=$?
if [[ $VERIFY_EXIT -eq 0 ]]; then
    echo "✅ Structure verification passed"
else
    echo "⚠️ Structure verification returned exit code $VERIFY_EXIT"
fi

echo ""
echo "2️⃣ Benchmark smoke test"
echo "-----------------------"
BENCHMARK_EXIT=0
../../workflow benchmark-stress \
    --impl ../../implementations/python \
    --timeout 180 \
    --output performance_report_test.txt \
    --json performance_data_test.json \
    > benchmark_output.txt 2>&1 || BENCHMARK_EXIT=$?

if [[ $BENCHMARK_EXIT -eq 0 ]]; then
    echo "✅ Benchmark smoke test completed"
else
    echo "⚠️ Benchmark smoke test returned exit code $BENCHMARK_EXIT"
fi

if [[ -f "performance_data_test.json" ]]; then
    IMPLEMENTATIONS=$(bun -e 'const data = JSON.parse(await Bun.file("performance_data_test.json").text()); console.log(Array.isArray(data) ? data.length : 1)')
    echo "📊 Benchmark JSON generated for $IMPLEMENTATIONS implementation(s)"
else
    echo "❌ Benchmark JSON output not generated"
fi

echo ""
echo "3️⃣ Result validation"
echo "--------------------"
VALIDATE_EXIT=0
../../workflow validate-results --benchmark-dir "$(pwd)" > validate_results.txt 2>&1 || VALIDATE_EXIT=$?
if [[ $VALIDATE_EXIT -eq 0 ]]; then
    echo "✅ Result validation passed"
else
    echo "⚠️ Result validation returned exit code $VALIDATE_EXIT"
fi

echo ""
echo "🎉 Local workflow smoke test completed"
echo "Artifacts:"
echo "  - .github/test-output/verification_results.txt"
echo "  - .github/test-output/performance_report_test.txt"
echo "  - .github/test-output/performance_data_test.json"
echo "  - .github/test-output/benchmark_output.txt"
echo "  - .github/test-output/validate_results.txt"

cd ../..
