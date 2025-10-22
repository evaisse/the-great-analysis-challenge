#!/usr/bin/env python3
"""
Combine individual benchmark JSON reports into a single file.
Used by bench.yaml workflow for selective benchmarking.
"""

import json
import glob
from pathlib import Path

def main():
    """Combine benchmark results from individual JSON files."""
    all_results = []
    
    for json_file in glob.glob('benchmark_reports/performance_data_*.json'):
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
    with open('benchmark_reports/performance_data.json', 'w') as f:
        json.dump(all_results, f, indent=2)

    print(f'Combined {len(all_results)} implementation results')

if __name__ == "__main__":
    main()