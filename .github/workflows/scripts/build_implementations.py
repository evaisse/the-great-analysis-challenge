#!/usr/bin/env python3
"""
Build implementations with proper error handling and logging.
Used by workflows for Docker build validation.
"""

import os
import subprocess
import sys

def discover_implementations():
    """Discover implementations from directory structure."""
    implementations = []
    impl_dir = "implementations"
    
    if not os.path.exists(impl_dir):
        print(f"❌ Implementations directory not found: {impl_dir}")
        return implementations
    
    for name in sorted(os.listdir(impl_dir)):
        impl_path = os.path.join(impl_dir, name)
        dockerfile_path = os.path.join(impl_path, "Dockerfile")
        
        if os.path.isdir(impl_path) and os.path.exists(dockerfile_path):
            implementations.append((name, impl_path))
    
    return implementations

def filter_implementations(all_impls, changed_impls):
    """Filter implementations based on changes."""
    if changed_impls == "all":
        return all_impls
    
    changed_list = changed_impls.strip().split()
    return [(name, path) for name, path in all_impls if name in changed_list]

def build_implementation(name, path):
    """Build a single implementation."""
    print(f"\n🏗️ Building {name}...")
    
    try:
        # Change to implementation directory
        original_dir = os.getcwd()
        os.chdir(path)
        
        # Build Docker image
        result = subprocess.run(
            ["docker", "build", "-t", f"chess-{name}-test", ".", "--quiet"],
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes timeout per build
        )
        
        os.chdir(original_dir)
        
        if result.returncode == 0:
            print(f"✅ {name}: Build successful")
            
            # Cleanup image
            subprocess.run(
                ["docker", "rmi", f"chess-{name}-test"],
                capture_output=True
            )
            return True
        else:
            print(f"❌ {name}: Build failed")
            if result.stderr:
                print(f"Error: {result.stderr.strip()}")
            return False
            
    except subprocess.TimeoutExpired:
        print(f"⏰ {name}: Build timed out")
        os.chdir(original_dir)
        return False
    except Exception as e:
        print(f"💥 {name}: Build error - {e}")
        os.chdir(original_dir)
        return False

def main():
    """Main function to build implementations."""
    changed_implementations = sys.argv[1] if len(sys.argv) > 1 else "all"
    
    all_implementations = discover_implementations()
    
    if not all_implementations:
        print("❌ No implementations found!")
        return 1
    
    # Filter based on changes
    implementations = filter_implementations(all_implementations, changed_implementations)
    
    if not implementations:
        print("❌ No changed implementations to build!")
        return 1
    
    print(f"Found {len(implementations)} implementations to build")
    
    success_count = 0
    total_count = len(implementations)
    
    for name, path in implementations:
        if build_implementation(name, path):
            success_count += 1
    
    print(f"\n📊 Results: {success_count}/{total_count} builds successful")
    
    if success_count == total_count:
        print("🎉 All builds passed!")
        return 0
    else:
        print("❌ Some builds failed")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)