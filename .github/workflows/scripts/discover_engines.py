#!/usr/bin/env python3
"""
Discover engine names for functionality testing matrix.
Returns a simple list of engine names.
"""

import os
import json

def discover_implementations():
    """Discover implementations from directory structure."""
    implementations = []
    impl_dir = "implementations"
    
    if not os.path.exists(impl_dir):
        return implementations
    
    for name in sorted(os.listdir(impl_dir)):
        impl_path = os.path.join(impl_dir, name)
        dockerfile_path = os.path.join(impl_path, "Dockerfile")
        
        if os.path.isdir(impl_path) and os.path.exists(dockerfile_path):
            implementations.append(name)
    
    return implementations

def main():
    """Main function to generate engine matrix."""
    # Discover all implementations
    implementations = discover_implementations()
    matrix = {"engine": implementations}
    print(json.dumps(matrix))

if __name__ == "__main__":
    main()