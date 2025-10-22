#!/usr/bin/env python3
"""
Run structure verification and count results.
"""

import os
import subprocess
from typing import Dict


def verify_implementations() -> Dict:
    """Run structure verification and count results."""
    print("=== Running Implementation Structure Verification ===")
    
    # Run verification script
    try:
        cmd = ["python3", "test/verify_implementations.py"]
        print(f"🔧 Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        
        if result.stdout.strip():
            print(f"📤 Verification output:\n{result.stdout}")
        if result.stderr.strip():
            print(f"⚠️ Verification stderr:\n{result.stderr}")
            
        with open("verification_results.txt", "w") as f:
            f.write(result.stdout)
            if result.stderr:
                f.write(result.stderr)
    except Exception as e:
        print(f"Verification script error: {e}")
        with open("verification_results.txt", "w") as f:
            f.write(f"Verification failed: {e}")
    
    # Count implementations by status
    try:
        with open("verification_results.txt", "r") as f:
            content = f.read()
        
        excellent = content.count("🟢") + content.count("excellent")
        good = content.count("🟡") + content.count("good")
        needs_work = content.count("🔴") + content.count("needs_work")
        total = excellent + good + needs_work
        
    except Exception:
        excellent = good = needs_work = total = 0
    
    print(f"=== Verification Summary ===")
    print(f"Total implementations: {total}")
    print(f"🟢 Excellent: {excellent}")
    print(f"🟡 Good: {good}")
    print(f"🔴 Needs work: {needs_work}")
    
    # Print verification results
    try:
        with open("verification_results.txt", "r") as f:
            print(f.read())
    except Exception:
        pass
    
    return {
        "excellent_count": excellent,
        "good_count": good,
        "needs_work_count": needs_work,
        "total_count": total
    }


def write_github_output(key: str, value: str):
    """Write to GitHub Actions output file."""
    github_output = os.environ.get('GITHUB_OUTPUT')
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"{key}={value}\n")
    else:
        print(f"Would set GitHub output: {key}={value}")


def main(args):
    """Main function for verify-implementations command."""
    result = verify_implementations()
    
    # Write GitHub outputs
    write_github_output("excellent_count", str(result["excellent_count"]))
    write_github_output("good_count", str(result["good_count"]))
    write_github_output("needs_work_count", str(result["needs_work_count"]))
    write_github_output("total_count", str(result["total_count"]))
    
    return result


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Run structure verification')
    args = parser.parse_args()
    
    main(args)