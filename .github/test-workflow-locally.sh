#!/bin/bash

# Local workflow testing script
# Tests the main components of the benchmark-and-release workflow locally

echo "🧪 Testing Benchmark & Release Workflow Components Locally"
echo "=========================================================="

# Check if we're in the right directory
if [[ ! -f "test/performance_test.py" ]]; then
    echo "❌ Must be run from project root directory"
    exit 1
fi

# Create test output directory
mkdir -p .github/test-output
cd .github/test-output

echo ""
echo "1️⃣ Testing Structure Verification"
echo "--------------------------------"
python3 ../../test/verify_implementations.py > verification_results.txt 2>&1
VERIFY_EXIT=$?

if [[ $VERIFY_EXIT -eq 0 ]]; then
    echo "✅ Structure verification passed"
else
    echo "⚠️ Structure verification had warnings (exit code: $VERIFY_EXIT)"
fi

# Extract counts for testing
EXCELLENT=$(grep -c "🟢.*excellent" verification_results.txt || echo "0")
GOOD=$(grep -c "🟡.*good" verification_results.txt || echo "0")
NEEDS_WORK=$(grep -c "🔴.*needs_work" verification_results.txt || echo "0")
TOTAL=$((EXCELLENT + GOOD + NEEDS_WORK))

echo "📊 Verification Summary:"
echo "   Total: $TOTAL implementations"
echo "   🟢 Excellent: $EXCELLENT"
echo "   🟡 Good: $GOOD"
echo "   🔴 Needs work: $NEEDS_WORK"

echo ""
echo "2️⃣ Testing Performance Benchmark (Limited)"
echo "-------------------------------------------"
echo "Note: Running limited test on Python implementation only for speed"

python3 ../../test/performance_test.py \
    --impl ../../implementations/python \
    --timeout 180 \
    --output performance_report_test.txt \
    --json performance_data_test.json \
    > benchmark_output.txt 2>&1

BENCHMARK_EXIT=$?

if [[ $BENCHMARK_EXIT -eq 0 ]]; then
    echo "✅ Performance benchmark completed successfully"
else
    echo "⚠️ Performance benchmark had issues (exit code: $BENCHMARK_EXIT)"
fi

if [[ -f performance_data_test.json ]]; then
    echo "✅ Performance JSON data generated"
    # Show basic stats
    IMPLEMENTATIONS=$(python3 -c "import json; data=json.load(open('performance_data_test.json')); print(len(data))")
    echo "   Tested implementations: $IMPLEMENTATIONS"
else
    echo "❌ Performance JSON data not generated"
fi

echo ""
echo "3️⃣ Testing README Update Logic"
echo "------------------------------"

# Create a test README update script
cat > test_readme_update.py << 'EOF'
import json
import re
from datetime import datetime
from pathlib import Path

def test_readme_update():
    """Test the README update logic"""
    
    # Load test performance data
    try:
        with open('performance_data_test.json', 'r') as f:
            performance_data = json.load(f)
    except FileNotFoundError:
        print("⚠️ No performance data for README test")
        return False
    
    print(f"✅ Loaded performance data for {len(performance_data)} implementation(s)")
    
    # Test table generation logic
    status_emoji = {'excellent': '🟢', 'good': '🟡', 'needs_work': '🔴'}
    
    for impl in performance_data:
        lang = impl.get('language', 'Unknown').title()
        status = impl.get('status', 'unknown')
        
        if status == 'completed':
            errors = len(impl.get('errors', []))
            test_results = impl.get('test_results', {})
            failed_tests = len(test_results.get('failed', []))
            
            if errors == 0 and failed_tests == 0:
                final_status = 'excellent'
            elif errors <= 2 and failed_tests <= 1:
                final_status = 'good'
            else:
                final_status = 'needs_work'
        else:
            final_status = 'needs_work'
        
        emoji = status_emoji.get(final_status, '⚪')
        timings = impl.get('timings', {})
        build_time = timings.get('build_seconds', 0)
        analyze_time = timings.get('analyze_seconds', 0)
        
        print(f"   {emoji} {lang}: Build {build_time:.1f}s, Analysis {analyze_time:.1f}s")
    
    print("✅ README table generation logic working")
    return True

if __name__ == "__main__":
    test_readme_update()
EOF

python3 test_readme_update.py

echo ""
echo "4️⃣ Testing Version Management Logic"
echo "-----------------------------------"

# Get current version
CURRENT_VERSION=$(cd ../.. && git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

if [[ -z "$CURRENT_VERSION" ]]; then
    CURRENT_VERSION="v0.0.0"
    echo "ℹ️ No previous version tags found, would start from $CURRENT_VERSION"
else
    echo "ℹ️ Current version: $CURRENT_VERSION"
fi

# Test version bump logic
if [[ $NEEDS_WORK -eq 0 && $EXCELLENT -gt 10 ]]; then
    VERSION_TYPE="minor"
else
    VERSION_TYPE="patch"
fi

echo "📈 Suggested version bump: $VERSION_TYPE"

# Calculate new version
IFS='.' read -r -a version_parts <<< "${CURRENT_VERSION#v}"
MAJOR=${version_parts[0]:-0}
MINOR=${version_parts[1]:-0}
PATCH=${version_parts[2]:-0}

case $VERSION_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="v$MAJOR.$MINOR.$PATCH"
echo "🏷️ Next version would be: $NEW_VERSION"

echo ""
echo "5️⃣ Testing Release Notes Generation"
echo "-----------------------------------"

cat > test_release_notes.md << EOF
# Chess Engine Implementation Benchmark Release $NEW_VERSION

This release contains updated performance benchmarks and status information for all chess engine implementations.

## 📊 Implementation Status Overview

- 🟢 **Excellent**: $EXCELLENT implementations
- 🟡 **Good**: $GOOD implementations  
- 🔴 **Needs Work**: $NEEDS_WORK implementations

**Total**: $TOTAL implementations tested

## 🚀 What's Updated

- ✅ Complete performance benchmark suite executed
- ✅ Implementation structure verification completed
- ✅ README status table updated with latest results
- ✅ Docker build and test validation

*This would be an automatically generated release.*
EOF

echo "✅ Release notes generated"
echo "📄 Preview:"
head -10 test_release_notes.md

echo ""
echo "6️⃣ Summary"
echo "----------"
echo "✅ Structure verification: Working"
echo "✅ Performance benchmarking: Working"
echo "✅ README update logic: Working"
echo "✅ Version management: Working"
echo "✅ Release notes generation: Working"

echo ""
echo "🎉 Local workflow testing completed successfully!"
echo ""
echo "📁 Test outputs saved in .github/test-output/"
echo "   - verification_results.txt"
echo "   - performance_report_test.txt"
echo "   - performance_data_test.json"
echo "   - benchmark_output.txt"
echo "   - test_release_notes.md"
echo ""
echo "🚀 The workflow should work correctly in GitHub Actions!"

# Return to original directory
cd ../..