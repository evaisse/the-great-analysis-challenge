#!/usr/bin/env python3
"""
Create release version, commit changes, and push tag.
"""

import os
import re
import subprocess
import glob


def create_release(version_type: str = "patch", readme_changed: str = "false",
                  excellent_count: int = 0, good_count: int = 0, 
                  needs_work_count: int = 0, total_count: int = 0) -> bool:
    """Create release version, commit changes, and push tag."""
    print("=== Creating Release ===")
    
    # Get current version
    try:
        result = subprocess.run([
            "git", "tag", "--sort=-version:refname"
        ], capture_output=True, text=True, check=True)
        tags = [line for line in result.stdout.split('\n') 
               if re.match(r'^v\d+\.\d+\.\d+$', line.strip())]
        current_version = tags[0] if tags else "v0.0.0"
    except Exception:
        current_version = "v0.0.0"
    
    # Calculate new version
    version_parts = current_version[1:].split('.')
    major = int(version_parts[0]) if len(version_parts) > 0 else 0
    minor = int(version_parts[1]) if len(version_parts) > 1 else 0
    patch = int(version_parts[2]) if len(version_parts) > 2 else 0
    
    if version_type == "major":
        major += 1
        minor = 0
        patch = 0
    elif version_type == "minor":
        minor += 1
        patch = 0
    else:  # patch
        patch += 1
    
    new_version = f"v{major}.{minor}.{patch}"
    
    # Configure git and commit changes if README was updated
    if readme_changed == "true":
        subprocess.run(["git", "config", "--local", "user.email", "action@github.com"], check=True)
        subprocess.run(["git", "config", "--local", "user.name", "GitHub Action"], check=True)
        
        # Copy benchmark reports to repo
        os.makedirs("benchmark_reports", exist_ok=True)
        for pattern in ["*.txt", "*.json"]:
            for file_path in glob.glob(f"benchmark_artifacts/**/{pattern}", recursive=True):
                dest_path = os.path.join("benchmark_reports", os.path.basename(file_path))
                try:
                    with open(file_path, "r") as src, open(dest_path, "w") as dst:
                        dst.write(src.read())
                except Exception:
                    pass
        
        subprocess.run(["git", "add", "benchmark_reports/", "README.md"], check=True)
        
        commit_message = f"""chore: update implementation status from benchmark suite

Benchmark results summary:
- Total implementations: {total_count}
- 🟢 Excellent: {excellent_count}
- 🟡 Good: {good_count}  
- 🔴 Needs work: {needs_work_count}

Performance testing completed with status updates."""
        
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        subprocess.run(["git", "push", "origin", "master"], check=True)
        print("✅ Changes committed and pushed")
    
    # Create and push tag
    subprocess.run(["git", "tag", "-a", new_version, "-m", f"Release {new_version} - Benchmark Update"], check=True)
    subprocess.run(["git", "push", "origin", new_version], check=True)
    print(f"✅ Release tag {new_version} created")
    
    return True


def write_github_output(key: str, value: str):
    """Write to GitHub Actions output file."""
    github_output = os.environ.get('GITHUB_OUTPUT')
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"{key}={value}\n")
    else:
        print(f"Would set GitHub output: {key}={value}")


def main(args):
    """Main function for create-release command."""
    success = create_release(
        args.version_type, args.readme_changed,
        args.excellent_count, args.good_count,
        args.needs_work_count, args.total_count
    )
    return 0 if success else 1


if __name__ == "__main__":
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description='Create and tag a release')
    parser.add_argument('--version-type', default='patch', choices=['major', 'minor', 'patch'])
    parser.add_argument('--readme-changed', default='false', help='Whether README was changed')
    parser.add_argument('--excellent-count', type=int, default=0)
    parser.add_argument('--good-count', type=int, default=0)
    parser.add_argument('--needs-work-count', type=int, default=0)
    parser.add_argument('--total-count', type=int, default=0)
    
    args = parser.parse_args()
    sys.exit(main(args))