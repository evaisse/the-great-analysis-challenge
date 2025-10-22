#!/usr/bin/env python3
"""
Reusable change detection logic for both test and bench workflows.
Returns changed implementations and generates matrix.
"""

import os
import sys
import subprocess

def get_changed_files(event_name, base_sha=None, head_sha=None, before_sha=None):
    """Get changed files based on event type."""
    try:
        if event_name == "pull_request" and base_sha and head_sha:
            cmd = ["git", "diff", "--name-only", base_sha, head_sha, "--", "implementations/"]
        elif before_sha and before_sha != "0000000000000000000000000000000000000000":
            cmd = ["git", "diff", "--name-only", before_sha, "HEAD", "--", "implementations/"]
        else:
            cmd = ["git", "diff", "--name-only", "HEAD~1", "HEAD", "--", "implementations/"]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout.strip().split('\n') if result.stdout.strip() else []
    except Exception as e:
        print(f"Error getting changed files: {e}")
        return []

def extract_changed_implementations(changed_files):
    """Extract implementation names from changed file paths."""
    implementations = set()
    for file_path in changed_files:
        if file_path.startswith("implementations/"):
            parts = file_path.split('/')
            if len(parts) >= 2:
                implementations.add(parts[1])
    return sorted(list(implementations))

def main():
    """Main function to detect changes and output results."""
    import json
    
    # Get arguments
    event_name = sys.argv[1] if len(sys.argv) > 1 else ""
    test_all = sys.argv[2] if len(sys.argv) > 2 else "false"
    base_sha = sys.argv[3] if len(sys.argv) > 3 else ""
    head_sha = sys.argv[4] if len(sys.argv) > 4 else ""
    before_sha = sys.argv[5] if len(sys.argv) > 5 else ""
    
    # Determine if we should test all implementations
    if test_all == "true" or event_name in ["schedule", "workflow_dispatch"]:
        print("Testing all implementations")
        changed_implementations = "all"
        has_changes = True
    else:
        changed_files = get_changed_files(event_name, base_sha, head_sha, before_sha)
        changed_implementations_list = extract_changed_implementations(changed_files)
        
        if changed_implementations_list:
            changed_implementations = " ".join(changed_implementations_list)
            has_changes = True
            print(f"Changed implementations: {changed_implementations}")
        else:
            changed_implementations = ""
            has_changes = False
            print("No implementation changes detected")
    
    # Output results
    result = {
        "implementations": changed_implementations,
        "has_changes": has_changes
    }
    
    print(json.dumps(result))

if __name__ == "__main__":
    main()