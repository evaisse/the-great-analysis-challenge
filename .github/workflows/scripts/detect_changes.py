#!/usr/bin/env python3
"""
Detect changed implementations based on git diff.
"""

import os
import subprocess
from typing import Dict


def detect_changes(event_name: str, test_all: str = "false", 
                  base_sha: str = "", head_sha: str = "", before_sha: str = "") -> Dict:
    """Detect changed implementations based on git diff."""
    print("=== Detecting Changed Implementations ===")
    
    # Determine if we should test all implementations
    if test_all == "true" or event_name in ["schedule", "workflow_dispatch"]:
        changed_implementations = "all"
        has_changes = True
    else:
        # Get changed files
        try:
            if event_name == "pull_request" and base_sha and head_sha:
                cmd = ["git", "diff", "--name-only", base_sha, head_sha, "--", "implementations/"]
            elif before_sha and before_sha != "0000000000000000000000000000000000000000":
                cmd = ["git", "diff", "--name-only", before_sha, "HEAD", "--", "implementations/"]
            else:
                cmd = ["git", "diff", "--name-only", "HEAD~1", "HEAD", "--", "implementations/"]
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            changed_files = result.stdout.strip().split('\n') if result.stdout.strip() else []
            
            # Extract implementation names
            implementations = set()
            for file_path in changed_files:
                if file_path.startswith("implementations/"):
                    parts = file_path.split('/')
                    if len(parts) >= 2:
                        implementations.add(parts[1])
            
            changed_implementations = " ".join(sorted(implementations))
            has_changes = len(implementations) > 0
            
        except Exception as e:
            print(f"Error detecting changes: {e}")
            changed_implementations = ""
            has_changes = False
    
    result = {
        "implementations": changed_implementations,
        "has_changes": str(has_changes).lower()
    }
    
    print(f"Changed implementations: {changed_implementations}")
    print(f"Has changes: {has_changes}")
    
    return result


def write_github_output(key: str, value: str):
    """Write to GitHub Actions output file."""
    github_output = os.environ.get('GITHUB_OUTPUT')
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"{key}={value}\n")
    else:
        print(f"Would set GitHub output: {key}={value}")


def main(args):
    """Main function for detect-changes command."""
    result = detect_changes(args.event_name, args.test_all, 
                           args.base_sha, args.head_sha, args.before_sha)
    
    # Write GitHub outputs
    write_github_output("implementations", result["implementations"])
    write_github_output("has-changes", result["has_changes"])
    
    return result


if __name__ == "__main__":
    import argparse
    import json
    
    parser = argparse.ArgumentParser(description='Detect changed implementations')
    parser.add_argument('event_name', help='GitHub event name')
    parser.add_argument('--test-all', default='false', help='Test all implementations')
    parser.add_argument('--base-sha', default='', help='Base SHA for PR')
    parser.add_argument('--head-sha', default='', help='Head SHA for PR')
    parser.add_argument('--before-sha', default='', help='Before SHA for push')
    
    args = parser.parse_args()
    result = main(args)
    print(json.dumps(result))