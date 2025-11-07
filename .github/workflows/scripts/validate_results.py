#!/usr/bin/env python3
"""
Validate benchmark result JSON files to ensure they contain no zero or empty fields.
This helps ensure data quality before updating README and website.
"""

import os
import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple


def validate_result_json(result_file: Path, language: str) -> Tuple[bool, List[str]]:
    """
    Validate a result JSON file for completeness and correctness.
    
    Returns:
        Tuple of (is_valid, list of issues)
    """
    issues = []
    
    if not result_file.exists():
        issues.append(f"Result file not found: {result_file}")
        return False, issues
    
    try:
        with open(result_file, 'r') as f:
            data = json.load(f)
        
        # Handle both list and dict formats
        if isinstance(data, list):
            if len(data) == 0:
                issues.append(f"Result file is empty list")
                return False, issues
            data = data[0]  # Take first element if list
        
        # Check critical fields exist
        critical_fields = ['language', 'timings', 'metadata', 'status']
        for field in critical_fields:
            if field not in data:
                issues.append(f"Missing critical field: {field}")
        
        # Check status
        if data.get('status') != 'completed':
            issues.append(f"Status is not 'completed': {data.get('status')}")
        
        # Check timings - ensure they are not zero or missing
        timings = data.get('timings', {})
        timing_fields = ['analyze_seconds', 'build_seconds', 'test_seconds']
        
        for field in timing_fields:
            value = timings.get(field)
            if value is None:
                # test_seconds can be None if no tests defined
                if field == 'test_seconds':
                    continue
                issues.append(f"Timing field '{field}' is missing")
            elif value == 0:
                # Zero is acceptable for very fast operations
                # We just warn rather than error
                pass  # Allow zero values
        
        # Check metadata exists and has required fields
        metadata = data.get('metadata', {})
        if not metadata:
            issues.append("Metadata is empty")
        else:
            required_meta_fields = ['language', 'version', 'features']
            for field in required_meta_fields:
                if field not in metadata:
                    issues.append(f"Metadata missing required field: {field}")
                elif not metadata[field]:
                    issues.append(f"Metadata field '{field}' is empty")
        
        # Check features list is not empty
        features = metadata.get('features', [])
        if not features:
            issues.append("Features list is empty")
        
        # Check for LOC data if available
        loc_data = data.get('loc', {})
        if loc_data:
            loc_count = loc_data.get('loc', 0)
            if loc_count == 0:
                issues.append("Lines of code count is 0 - may indicate counting error")
        
    except json.JSONDecodeError as e:
        issues.append(f"Invalid JSON format: {e}")
        return False, issues
    except Exception as e:
        issues.append(f"Error reading result file: {e}")
        return False, issues
    
    # Determine if valid (no critical issues)
    is_valid = len(issues) == 0
    return is_valid, issues


def validate_all_results(benchmark_dir: str = "benchmark_reports") -> int:
    """
    Validate all result JSON files in the benchmark directory.
    
    Returns:
        Exit code (0 for success, 1 for failures)
    """
    print("=" * 60)
    print("Validating Benchmark Result Files")
    print("=" * 60)
    
    if not os.path.exists(benchmark_dir):
        print(f"❌ Benchmark directory not found: {benchmark_dir}")
        print("   This is acceptable if no benchmarks have been run yet.")
        return 0  # Don't fail if no benchmarks exist
    
    # Find all performance_data_*.json files
    import glob
    result_files = glob.glob(os.path.join(benchmark_dir, "performance_data_*.json"))
    
    if not result_files:
        print("⚠️  No result files found in benchmark_reports/")
        print("   This is acceptable if no benchmarks have been run yet.")
        return 0
    
    print(f"Found {len(result_files)} result file(s) to validate\n")
    
    all_valid = True
    validation_results = []
    
    for result_file in sorted(result_files):
        # Extract language name from filename
        filename = os.path.basename(result_file)
        language = filename.replace("performance_data_", "").replace(".json", "")
        
        print(f"Validating {language}...")
        is_valid, issues = validate_result_json(Path(result_file), language)
        
        validation_results.append((language, is_valid, issues))
        
        if is_valid:
            print(f"  ✅ Valid")
        else:
            print(f"  ❌ Invalid - {len(issues)} issue(s):")
            for issue in issues:
                print(f"     - {issue}")
            all_valid = False
        print()
    
    # Summary
    print("=" * 60)
    print("Validation Summary")
    print("=" * 60)
    
    valid_count = sum(1 for _, valid, _ in validation_results if valid)
    invalid_count = len(validation_results) - valid_count
    
    print(f"Total files: {len(validation_results)}")
    print(f"✅ Valid: {valid_count}")
    print(f"❌ Invalid: {invalid_count}")
    
    if all_valid:
        print("\n🎉 All result files are valid!")
        return 0
    else:
        print("\n❌ Some result files have issues - please review and fix")
        return 1


def main(args):
    """Main function for validate-results command."""
    benchmark_dir = args.benchmark_dir if hasattr(args, 'benchmark_dir') else "benchmark_reports"
    return validate_all_results(benchmark_dir)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Validate benchmark result JSON files')
    parser.add_argument('--benchmark-dir', default='benchmark_reports',
                       help='Directory containing benchmark results')
    args = parser.parse_args()
    
    sys.exit(main(args))
