#!/usr/bin/env python3
"""
Combine benchmark artifacts from multiple jobs.
"""

import os
import json
import glob


def combine_results() -> bool:
    """Combine benchmark artifacts from multiple jobs."""
    print("=== Combining Benchmark Results ===")
    
    # Create combined reports directory
    os.makedirs("reports", exist_ok=True)
    
    # Copy all individual reports
    try:
        for pattern in ["*.txt", "*.json"]:
            for file_path in glob.glob(f"benchmark_artifacts/**/{pattern}", recursive=True):
                dest_path = os.path.join("reports", os.path.basename(file_path))
                with open(file_path, "r") as src, open(dest_path, "w") as dst:
                    dst.write(src.read())
    except Exception as e:
        print(f"Error copying files: {e}")
    
    # Combine JSON reports
    all_results = []
    for json_file in glob.glob('reports/*.json'):
        if json_file.endswith('performance_data.json'):
            continue
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
                if isinstance(data, list):
                    all_results.extend(data)
                else:
                    all_results.append(data)
        except Exception as e:
            print(f'Error reading {json_file}: {e}')
    
    # Save combined results
    if all_results:
        with open('reports/performance_data.json', 'w') as f:
            json.dump(all_results, f, indent=2)
        print(f'Combined {len(all_results)} implementation results')
    
    print("✅ Benchmark results combined")
    return True


def main(args):
    """Main function for combine-results command."""
    success = combine_results()
    return 0 if success else 1


if __name__ == "__main__":
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description='Combine benchmark artifacts')
    args = parser.parse_args()
    
    sys.exit(main(args))
