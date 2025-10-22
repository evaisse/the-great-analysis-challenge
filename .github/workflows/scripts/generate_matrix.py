#!/usr/bin/env python3
"""
Generate GitHub Actions matrix for parallel jobs.
"""

import os
import json
from typing import Dict, List


def discover_implementations() -> List[Dict]:
    """Discover implementations from directory structure."""
    implementations = []
    impl_dir = "implementations"
    
    if not os.path.exists(impl_dir):
        return implementations
    
    for name in os.listdir(impl_dir):
        impl_path = os.path.join(impl_dir, name)
        dockerfile_path = os.path.join(impl_path, "Dockerfile")
        
        if os.path.isdir(impl_path) and os.path.exists(dockerfile_path):
            implementations.append({
                "name": name.title(),
                "directory": impl_path,
                "dockerfile": "Dockerfile",
                "engine": name
            })
    
    return sorted(implementations, key=lambda x: x["name"])


def filter_implementations(all_impls: List[Dict], changed_impls: str) -> List[Dict]:
    """Filter implementations based on changes."""
    if changed_impls == "all":
        return all_impls
    
    changed_list = changed_impls.strip().split()
    return [impl for impl in all_impls if impl["engine"] in changed_list]


def generate_matrix(changed_implementations: str = "all") -> Dict:
    """Generate GitHub Actions matrix for parallel jobs."""
    print("=== Generating Matrix ===")
    
    # Discover implementations
    implementations = discover_implementations()
    
    # Filter based on changes
    if changed_implementations != "all":
        changed_list = changed_implementations.strip().split()
        implementations = [impl for impl in implementations if impl["engine"] in changed_list]
    
    # Generate matrix
    matrix = {"include": implementations}
    
    print(f"Generated matrix with {len(implementations)} implementations")
    
    return matrix


def write_github_output(key: str, value: str):
    """Write to GitHub Actions output file."""
    github_output = os.environ.get('GITHUB_OUTPUT')
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"{key}={value}\n")
    else:
        print(f"Would set GitHub output: {key}={value}")


def main(args):
    """Main function for generate-matrix command."""
    matrix = generate_matrix(args.changed_implementations)
    matrix_json = json.dumps(matrix)
    
    write_github_output("matrix", matrix_json)
    
    return matrix


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate GitHub Actions matrix')
    parser.add_argument('changed_implementations', nargs='?', default='all', 
                       help='Changed implementations (space-separated)')
    
    args = parser.parse_args()
    result = main(args)
    print(json.dumps(result))