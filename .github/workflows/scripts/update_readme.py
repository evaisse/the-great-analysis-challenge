#!/usr/bin/env python3
"""
Update README status table with latest benchmark results.
"""

import os
import json
import re
import subprocess
import glob
from pathlib import Path
from typing import Dict, List, Any

# Add scripts directory to path to import shared module
SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'scripts')
if os.path.exists(SCRIPTS_DIR):
    import sys
    sys.path.insert(0, SCRIPTS_DIR)
    try:
        from chess_metadata import get_metadata
    except ImportError:
        def get_metadata(impl_dir): return {}
else:
    def get_metadata(impl_dir): return {}

CUSTOM_EMOJIS: Dict[str, str] = {
    'python': '🐍',
    'crystal': '💠',
    'dart': '🎯',
    'elm': '🌳',
    'gleam': '✨',
    'go': '🐹',
    'haskell': '📐',
    'imba': '🪶',
    'javascript': '🟨',
    'julia': '🔮',
    'kotlin': '🧡',
    'lua': '🪐',
    'mojo': '🔥',
    'nim': '🦊',
    'php': '🐘',
    'rescript': '🧠',
    'ruby': '❤️',
    'rust': '🦀',
    'swift': '🐦',
    'typescript': '📘',
    'zig': '⚡'
}

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

def count_lines_of_code(impl_path: str) -> Dict[str, int]:
    """Count lines of code for an implementation."""
    extensions = {
        'crystal': ['.cr'],
        'dart': ['.dart'],
        'elm': ['.elm'],
        'gleam': ['.gleam'],
        'go': ['.go'],
        'haskell': ['.hs'],
        'julia': ['.jl'],
        'kotlin': ['.kt'],
        'lua': ['.lua'],
        'mojo': ['.mojo', '.🔥'],
        'nim': ['.nim'],
        'php': ['.php'],
        'python': ['.py'],
        'rescript': ['.res', '.resi'],
        'ruby': ['.rb'],
        'rust': ['.rs'],
        'swift': ['.swift'],
        'typescript': ['.ts'],
        'zig': ['.zig']
    }

    lang_name = os.path.basename(impl_path)
    exts = extensions.get(lang_name, [])
    total_loc = 0
    file_count = 0

    src_dir = os.path.join(impl_path, 'src')
    if not os.path.exists(src_dir):
        src_dir = impl_path

    for ext in exts:
        pattern = f"{src_dir}/**/*{ext}"
        for file in glob.glob(pattern, recursive=True):
            try:
                with open(file, 'r', encoding='utf-8', errors='ignore') as handle:
                    total_loc += len(handle.readlines())
                    file_count += 1
            except Exception:
                continue

    return {'loc': total_loc, 'files': file_count}

def load_performance_data():
    """Load performance benchmark data from individual files"""
    project_root = find_project_root()
    if project_root:
        benchmark_dir = os.path.join(project_root, 'reports')
    else:
        benchmark_dir = 'reports'
    performance_data = []
    
    if not os.path.exists(benchmark_dir):
        print("⚠️ Reports directory not found")
        return []
    
    # Load individual performance data files
    data_files = [
        path for path in glob.glob(os.path.join(benchmark_dir, '*.json'))
        if not path.endswith('performance_data.json')
    ]
    
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
    """Format time duration in milliseconds for better precision"""
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
                match = re.search(r'\*\*([^*]+)\*\*', line)
                if match:
                    language = match.group(1).strip().lower()
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
        project_root = find_project_root() or os.getcwd()
        
        # Generate status table
        status_emoji = {
            'excellent': '🟢',
            'good': '🟡', 
            'needs_work': '🔴'
        }
        
        # Create combined data set prioritizing verification results
        combined_data = {}
        for impl_data in performance_data:
            language = impl_data.get('language', '').lower()
            combined_data[language] = impl_data
        
        impl_dir = os.path.join(project_root, "implementations")
        all_languages = []
        if os.path.exists(impl_dir):
            all_languages = sorted([
                name.lower() for name in os.listdir(impl_dir)
                if os.path.isdir(os.path.join(impl_dir, name))
            ])
        
        if not all_languages:
            print("❌ Error: Could not discover any implementations")
            return False
        
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
            impl_path = os.path.join(impl_dir, language)
            
            # Metadata & Stats
            meta = get_metadata(impl_path)
            loc_data = count_lines_of_code(impl_path)
            
            # Status
            if verification_data and language in verification_data:
                status = verification_data[language]
            else:
                status = classify_implementation_status(impl_data)
            
            emoji = status_emoji.get(status, '❓')
            lang_emoji = CUSTOM_EMOJIS.get(language, '📦')
            
            # Timings
            timings = impl_data.get('timings', {})
            analyze_time = format_time(timings.get('analyze_seconds'))
            build_time = format_time(timings.get('build_seconds'))
            test_time = format_time(timings.get('test_seconds'))
            
            # Memory
            memory_data = impl_data.get('memory', {})
            peak_memory = 0
            for phase in ['build', 'test', 'analyze']:
                phase_mem = memory_data.get(phase, {})
                if isinstance(phase_mem, dict):
                    peak_memory = max(peak_memory, phase_mem.get('peak_memory_mb', 0))
            mem_disp = f"{int(round(peak_memory))}" if peak_memory > 0 else "-"

            # Features
            features = meta.get('features', []) if isinstance(meta.get('features'), list) else []
            feature_summary = ', '.join(features) if features else '-'
            
            lang_name = f"{lang_emoji} {language.title()}"
            table_rows.append(f"| {lang_name} | {emoji} | {loc_data['loc']} | {build_time} | {test_time} | {analyze_time} | {mem_disp} MB | {feature_summary} |")
        
        # Create table content
        table_header = """
| Language | Status | LOC | Build | Test | Analyze | Memory | Features |
|----------|--------|-----|-------|------|---------|--------|----------|"""
        
        new_table = table_header + "\n" + "\n".join(table_rows)
        
        readme_path = os.path.join(project_root, "README.md")
        
        if os.path.exists(readme_path):
            with open(readme_path, 'r') as f:
                content = f.read()
            
            if "The Great Analysis Challenge" not in content:
                print("⚠️ Warning: README doesn't contain expected project title")
                return False
            
            if "<!-- status-table-start -->" not in content:
                print("⚠️ Warning: README doesn't contain status table markers")
                return False
            
            pattern = r'(<!-- status-table-start -->).*?(<!-- status-table-end -->)'
            replacement = f'\\1\n{new_table}\n\\2'
            new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
            
            if new_content == content:
                print("⚠️ No changes detected in README content")
                return False
            
            with open(readme_path, 'w') as f:
                f.write(new_content)
            
            print("✅ README status table updated")
        else:
            print(f"❌ README.md not found at {readme_path}")
            return False
        
        return True
        
    except Exception as e:
        print(f"Error updating README: {e}")
        import traceback
        traceback.print_exc()
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
