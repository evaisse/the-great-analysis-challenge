#!/usr/bin/env python3
"""
Validate benchmark result JSON files to ensure they contain no zero or empty fields.
This helps ensure data quality before updating README and website.
"""

import os
import json
import sys
from pathlib import Path
from typing import List, Tuple


def validate_result_json(result_file: Path, language: str) -> Tuple[bool, List[str], List[str]]:
    """
    Validate a result JSON file for completeness and correctness.
    
    Returns:
        Tuple of (is_valid, list of blocking issues, list of non-blocking warnings)
    """
    issues = []
    warnings = []
    
    if not result_file.exists():
        issues.append(f"Result file not found: {result_file}")
        return False, issues, warnings
    
    try:
        with open(result_file, 'r') as f:
            data = json.load(f)
        
        # Handle both list and dict formats
        if isinstance(data, list):
            if len(data) == 0:
                issues.append(f"Result file is empty list")
                return False, issues, warnings
            data = data[0]  # Take first element if list
        
        # Check critical fields exist
        critical_fields = ['language', 'timings', 'metadata', 'status']
        for field in critical_fields:
            if field not in data:
                issues.append(f"Missing critical field: {field}")
        
        # Check status
        if data.get('status') != 'completed':
            issues.append(f"Status is not 'completed': {data.get('status')}")
        
        # Check timings - ensure they are not missing
        # This enforces benchmark output constraints at the CI level
        timings = data.get('timings', {})
        docker_data = data.get('docker', {}) if isinstance(data.get('docker', {}), dict) else {}
        make_build_skipped = bool(docker_data.get('make_build_skipped', False))

        if not make_build_skipped and timings.get('build_seconds') is None:
            issues.append("Required timing field 'build_seconds' is missing")
        if timings.get('test_seconds') is None:
            issues.append("Required timing field 'test_seconds' is missing")
        
        # Note: Zero values are acceptable for very fast operations
        # that complete in less than 1ms, so we don't flag them as issues
        # analyze_seconds is optional and not validated here
        
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
        
        # Check TOKENS metric in a non-blocking way.
        metrics = data.get('metrics', {})
        if not isinstance(metrics, dict) or not metrics:
            warnings.append("Metrics object missing - TOKENS may not be available in README")
        else:
            tokens_count = metrics.get("tokens_count")
            metric_version = metrics.get("metric_version")

            if tokens_count is None:
                warnings.append("metrics.tokens_count missing - README will display '-'")
            elif not isinstance(tokens_count, int) or tokens_count < 0:
                warnings.append(f"metrics.tokens_count should be a non-negative integer, got: {tokens_count}")

            if metric_version is None:
                warnings.append("metrics.metric_version missing")
            elif not isinstance(metric_version, str) or not metric_version.strip():
                warnings.append(f"metrics.metric_version should be a non-empty string, got: {metric_version}")
        
    except json.JSONDecodeError as e:
        issues.append(f"Invalid JSON format: {e}")
        return False, issues, warnings
    except Exception as e:
        issues.append(f"Error reading result file: {e}")
        return False, issues, warnings
    
    # Determine if valid (no critical issues)
    is_valid = len(issues) == 0
    return is_valid, issues, warnings


def validate_all_results(benchmark_dir: str = "reports") -> int:
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
    
    # Find all implementation JSON files
    import glob
    result_files = [
        path for path in glob.glob(os.path.join(benchmark_dir, "*.json"))
        if not path.endswith("performance_data.json")
    ]
    
    if not result_files:
        print("⚠️  No result files found in reports/")
        print("   This is acceptable if no benchmarks have been run yet.")
        return 0
    
    print(f"Found {len(result_files)} result file(s) to validate\n")
    
    all_valid = True
    validation_results: List[Tuple[str, bool, List[str], List[str]]] = []
    
    for result_file in sorted(result_files):
        # Extract language name from filename
        filename = os.path.basename(result_file)
        language = filename.replace(".json", "")
        
        print(f"Validating {language}...")
        is_valid, issues, warnings = validate_result_json(Path(result_file), language)
        
        validation_results.append((language, is_valid, issues, warnings))
        
        if is_valid:
            print(f"  ✅ Valid")
        else:
            print(f"  ❌ Invalid - {len(issues)} issue(s):")
            for issue in issues:
                print(f"     - {issue}")
            all_valid = False
        if warnings:
            print(f"  ⚠️ Warnings - {len(warnings)}:")
            for warning in warnings:
                print(f"     - {warning}")
        print()
    
    # Summary
    print("=" * 60)
    print("Validation Summary")
    print("=" * 60)
    
    valid_count = sum(1 for _, valid, _, _ in validation_results if valid)
    invalid_count = len(validation_results) - valid_count
    warning_count = sum(len(warnings) for _, _, _, warnings in validation_results)
    
    print(f"Total files: {len(validation_results)}")
    print(f"✅ Valid: {valid_count}")
    print(f"❌ Invalid: {invalid_count}")
    print(f"⚠️ Warnings: {warning_count}")
    
    if all_valid:
        print("\n🎉 All result files are valid!")
        return 0
    else:
        print("\n❌ Some result files have issues - please review and fix")
        return 1


def main(args):
    """Main function for validate-results command."""
    benchmark_dir = args.benchmark_dir if hasattr(args, 'benchmark_dir') else "reports"
    return validate_all_results(benchmark_dir)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Validate benchmark result JSON files')
    parser.add_argument('--benchmark-dir', default='reports',
                       help='Directory containing benchmark results')
    args = parser.parse_args()
    
    sys.exit(main(args))
