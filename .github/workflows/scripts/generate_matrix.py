#!/usr/bin/env python3
"""
Generate dynamic test matrix from implementations directory structure.
Used by workflows to discover implementations without hardcoding.
"""

import os
import json
import sys

def discover_implementations():
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

def filter_implementations(all_impls, changed_impls):
    """Filter implementations based on changes."""
    if changed_impls == "all":
        return all_impls
    
    changed_list = changed_impls.strip().split()
    return [impl for impl in all_impls if impl["engine"] in changed_list]

def main():
    """Main function to generate matrix JSON."""
    # Get all implementations
    all_implementations = discover_implementations()
    changed_implementations = sys.argv[1] if len(sys.argv) > 1 else "all"

    # Filter based on changes
    filtered_implementations = filter_implementations(all_implementations, changed_implementations)

    # Generate matrix
    matrix = {"include": filtered_implementations}
    print(json.dumps(matrix))

if __name__ == "__main__":
    main()