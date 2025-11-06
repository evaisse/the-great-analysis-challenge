#!/usr/bin/env python3
"""
Update README status table with latest benchmark results.
"""

import os
import json
import re
import subprocess


def find_project_root():
    """Find the project root directory."""
    current_dir = os.getcwd()
    while current_dir != '/':
        if (os.path.exists(os.path.join(current_dir, ".git")) and 
            os.path.exists(os.path.join(current_dir, "implementations")) and
            os.path.exists(os.path.join(current_dir, "test"))):
            return current_dir
        current_dir = os.path.dirname(current_dir)
    return None


def load_performance_data():
    """Load performance benchmark data from individual files"""
    project_root = find_project_root()
    if project_root:
        benchmark_dir = os.path.join(project_root, 'benchmark_reports')
    else:
        benchmark_dir = 'benchmark_reports'
    performance_data = []
    
    if not os.path.exists(benchmark_dir):
        print("⚠️ Benchmark reports directory not found")
        return []
    
    # Load individual performance data files
    import glob
    data_files = glob.glob(os.path.join(benchmark_dir, 'performance_data_*.json'))
    
    for data_file in data_files:
        try:
            with open(data_file, 'r') as f:
                data = json.load(f)
                if isinstance(data, list) and len(data) > 0:
                    performance_data.extend(data)
                elif isinstance(data, dict):
                    performance_data.append(data)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"⚠️ Error loading {data_file}: {e}")
            continue
    
    if not performance_data:
        print("⚠️ No performance data found")
    else:
        print(f"✅ Loaded performance data for {len(performance_data)} implementations")
    
    return performance_data


def classify_implementation_status(impl_data):
    """Classify implementation status based on benchmark results and metadata"""
    # Check if build succeeded
    if impl_data.get('status') != 'completed':
        return 'needs_work'
    
    # Get metadata for feature analysis
    metadata = impl_data.get('metadata', {})
    features = metadata.get('features', [])
    
    # Required features for excellent status
    required_features = {'perft', 'fen', 'ai', 'castling', 'en_passant', 'promotion'}
    has_all_features = required_features.issubset(set(features))
    
    # Check for errors and test failures
    errors = len(impl_data.get('errors', []))
    test_results = impl_data.get('test_results', {})
    failed_tests = len(test_results.get('failed', []))
    passed_tests = len(test_results.get('passed', []))
    
    # Check if docker and build succeeded
    docker_success = impl_data.get('docker', {}).get('build_success', False)
    timings = impl_data.get('timings', {})
    build_time = timings.get('build_seconds')
    
    # Excellent: All features, no errors, builds successfully
    if (has_all_features and errors == 0 and failed_tests == 0 and 
        docker_success and build_time is not None and build_time >= 0):
        return 'excellent'
    
    # Good: Most features, minimal issues
    elif (len(features) >= 4 and errors <= 2 and failed_tests <= 2 and 
          docker_success):
        return 'good'
    
    # Needs work: Missing features or significant issues
    else:
        return 'needs_work'


def format_time(seconds):
    """Format time duration in milliseconds for better precision
    
    Args:
        seconds: Time in seconds, or None if data is not available
        
    Returns:
        Formatted time string or "-" if data is missing
    """
    if seconds is None:
        return "-"
    elif seconds == 0:
        return "<1ms"
    else:
        ms = seconds * 1000
        if ms < 1:
            return "<1ms"
        elif ms < 10:
            return f"{ms:.1f}ms"
        else:
            return f"{ms:.0f}ms"


def get_verification_status():
    """Get current verification status by running verify_implementations.py"""
    try:
        # Find the project root to run verification from correct directory
        project_root = find_project_root()
        if project_root:
            os.chdir(project_root)
        
        result = subprocess.run(['python3', 'test/verify_implementations.py'], 
                              capture_output=True, text=True, check=True)
        
        # Parse verification output for status
        verification_data = {}
        current_lang = None
        
        for line in result.stdout.split('\n'):
            if '**' in line and ('excellent' in line or 'good' in line or 'needs work' in line):
                # Extract language and status
                if 'excellent' in line:
                    status = 'excellent'
                elif 'good' in line:
                    status = 'good'
                else:
                    status = 'needs_work'
                
                # Extract language name (between ** markers)
                import re
                match = re.search(r'\*\*([^*]+)\*\*', line)
                if match:
                    language = match.group(1).strip()
                    verification_data[language] = status
        
        return verification_data
    except Exception as e:
        print(f"⚠️ Could not run verification: {e}")
        return {}


def update_readme() -> bool:
    """Update README status table and check if it was modified."""
    print("=== Updating README Status Table ===")
    
    try:
        performance_data = load_performance_data()
        verification_data = get_verification_status()
        
        # If we have verification data, use it as the source of truth
        if verification_data:
            print(f"✅ Using verification data for {len(verification_data)} implementations")
        
        # Generate status table
        status_emoji = {
            'excellent': '🟢',
            'good': '🟡', 
            'needs_work': '🔴'
        }
        
        # Create combined data set prioritizing verification results
        combined_data = {}
        
        # Start with performance data structure
        for impl_data in performance_data:
            language = impl_data.get('language', '').lower()
            combined_data[language] = impl_data
        
        # Add any missing languages from verification
        all_languages = ['crystal', 'dart', 'elm', 'gleam', 'go', 'haskell', 'julia', 
                        'kotlin', 'mojo', 'nim', 'python', 'rescript', 'ruby', 'rust', 
                        'swift', 'typescript', 'zig']
        
        for lang in all_languages:
            if lang not in combined_data:
                combined_data[lang] = {
                    'language': lang,
                    'timings': {},
                    'test_results': {'passed': [], 'failed': []},
                    'status': 'completed'
                }
        
        table_rows = []
        for language in sorted(all_languages):
            impl_data = combined_data.get(language, {})
            
            # Use verification status if available, otherwise classify from benchmark data
            if verification_data and language in verification_data:
                status = verification_data[language]
            else:
                status = classify_implementation_status(impl_data)
            
            emoji = status_emoji.get(status, '❓')
            
            timings = impl_data.get('timings', {})
            # Use None as default instead of 0 to distinguish missing data from zero time
            analyze_time = format_time(timings.get('analyze_seconds'))
            build_time = format_time(timings.get('build_seconds'))
            test_time = format_time(timings.get('test_seconds'))
            
            table_rows.append(f"| {language.title()} | {emoji} | {analyze_time} | {build_time} | {test_time} |")
        
        # Create table content
        table_header = """
| Language | Status | Analysis Time | Build Time | Test Time |
|----------|--------|---------------|------------|-----------|"""
        
        new_table = table_header + "\n" + "\n".join(table_rows)
        
        # Update README.md - ensure we're working with the project root README
        readme_path = os.path.join(os.getcwd(), "README.md")
        
        # If we're running from a subdirectory, find the project root
        if not os.path.exists(readme_path):
            # Look for the root directory by finding .git or workflow files
            current_dir = os.getcwd()
            while current_dir != '/':
                potential_readme = os.path.join(current_dir, "README.md")
                if (os.path.exists(potential_readme) and 
                    (os.path.exists(os.path.join(current_dir, ".git")) or 
                     os.path.exists(os.path.join(current_dir, "implementations")))):
                    readme_path = potential_readme
                    break
                current_dir = os.path.dirname(current_dir)
        
        print(f"📄 Using README path: {readme_path}")
        if os.path.exists(readme_path):
            with open(readme_path, 'r') as f:
                content = f.read()
            
            # Validate this is the correct README by checking for our project markers
            if "The Great Analysis Challenge" not in content:
                print("⚠️ Warning: README doesn't contain expected project title")
                print("⚠️ This might be the wrong README file")
                return False
            
            if "<!-- status-table-start -->" not in content:
                print("⚠️ Warning: README doesn't contain status table markers")
                print("⚠️ Skipping update to avoid overwriting wrong content")
                return False
            
            # Find and replace the status table
            pattern = r'(<!-- status-table-start -->).*?(<!-- status-table-end -->)'
            replacement = f'\\1\n{new_table}\n\\2'
            
            new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
            
            # Additional safety check
            if new_content == content:
                print("⚠️ No changes detected in README content")
                return False
            
            with open(readme_path, 'w') as f:
                f.write(new_content)
            
            print("✅ README status table updated")
        else:
            print(f"❌ README.md not found at {readme_path}")
            return False
        
        # Check if README was modified
        cmd = ["git", "diff", "--quiet", "README.md"]
        print(f"🔧 Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, check=False)
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