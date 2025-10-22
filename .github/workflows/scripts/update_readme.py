#!/usr/bin/env python3
"""
Update README status table with latest benchmark results.
"""

import os
import json
import re
import subprocess


def load_performance_data():
    """Load performance benchmark data"""
    try:
        with open('benchmark_reports/performance_data.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("⚠️ Performance data not found")
        return []


def classify_implementation_status(impl_data):
    """Classify implementation status based on benchmark results"""
    if impl_data.get('status') != 'completed':
        return 'needs_work'
    
    errors = len(impl_data.get('errors', []))
    test_results = impl_data.get('test_results', {})
    failed_tests = len(test_results.get('failed', []))
    
    if errors == 0 and failed_tests == 0:
        return 'excellent'
    elif errors <= 2 and failed_tests <= 1:
        return 'good'
    else:
        return 'needs_work'


def format_time(seconds):
    """Format time duration"""
    if seconds == 0:
        return "~0s"
    elif seconds < 1:
        return f"~{seconds:.1f}s"
    else:
        return f"~{seconds:.0f}s"


def update_readme() -> bool:
    """Update README status table and check if it was modified."""
    print("=== Updating README Status Table ===")
    
    try:
        performance_data = load_performance_data()
        
        # Generate status table
        status_emoji = {
            'excellent': '🟢',
            'good': '🟡', 
            'needs_work': '🔴'
        }
        
        table_rows = []
        for impl_data in sorted(performance_data, key=lambda x: x.get('language', '')):
            language = impl_data.get('language', 'Unknown')
            status = classify_implementation_status(impl_data)
            emoji = status_emoji.get(status, '❓')
            
            timings = impl_data.get('timings', {})
            build_time = format_time(timings.get('build_seconds', 0))
            test_time = format_time(timings.get('test_seconds', 0))
            
            test_results = impl_data.get('test_results', {})
            passed = len(test_results.get('passed', []))
            failed = len(test_results.get('failed', []))
            test_score = f"{passed}/{passed+failed}" if (passed + failed) > 0 else "0/0"
            
            table_rows.append(f"| {language.title()} | {emoji} | {build_time} | {test_time} | {test_score} |")
        
        # Create table content
        table_header = """
| Language | Status | Build Time | Test Time | Tests Passed |
|----------|--------|------------|-----------|--------------|"""
        
        new_table = table_header + "\n" + "\n".join(table_rows)
        
        # Update README.md
        readme_path = "README.md"
        if os.path.exists(readme_path):
            with open(readme_path, 'r') as f:
                content = f.read()
            
            # Find and replace the status table
            pattern = r'(<!-- status-table-start -->).*?(<!-- status-table-end -->)'
            replacement = f'\\1\n{new_table}\n\\2'
            
            new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
            
            with open(readme_path, 'w') as f:
                f.write(new_content)
            
            print("✅ README status table updated")
        
        # Check if README was modified
        result = subprocess.run(["git", "diff", "--quiet", "README.md"], 
                              capture_output=True, check=False)
        readme_changed = result.returncode != 0
        
        if readme_changed:
            print("✅ README.md has been updated")
        else:
            print("⚠️ README.md was not modified")
        
        return readme_changed
        
    except Exception as e:
        print(f"Error updating README: {e}")
        return False


def write_github_output(key: str, value: str):
    """Write to GitHub Actions output file."""
    github_output = os.environ.get('GITHUB_OUTPUT')
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"{key}={value}\n")
    else:
        print(f"Would set GitHub output: {key}={value}")


def main(args):
    """Main function for update-readme command."""
    readme_changed = update_readme()
    write_github_output("changed", str(readme_changed).lower())
    return 0


if __name__ == "__main__":
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description='Update README status table')
    args = parser.parse_args()
    
    sys.exit(main(args))