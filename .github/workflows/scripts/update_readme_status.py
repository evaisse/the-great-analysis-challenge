#!/usr/bin/env python3
"""
Update README.md status table with latest benchmark results.
Used by bench.yaml workflow to maintain up-to-date status information.
"""

import json
import re
from datetime import datetime
from pathlib import Path

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

def generate_status_table(performance_data):
    """Generate the implementation status table"""
    
    # Status emoji mapping
    status_emoji = {
        'excellent': '🟢',
        'good': '🟡',
        'needs_work': '🔴'
    }
    
    # Build table rows
    table_rows = []
    
    for impl in sorted(performance_data, key=lambda x: x.get('language', '')):
        lang = impl.get('language', 'Unknown').title()
        status = classify_implementation_status(impl)
        emoji = status_emoji.get(status, '⚪')
        
        # Extract timing data
        timings = impl.get('timings', {})
        analyze_time = format_time(timings.get('analyze_seconds', 0))
        build_time = format_time(timings.get('build_seconds', 0))
        
        # Features and compliance
        features = "✅ Complete" if status != 'needs_work' else "🔧 Issues"
        makefile = "✅ Full" if status != 'needs_work' else "❌ Missing"
        docker_status = "✅ Working"
        if impl.get('docker', {}).get('build_success') is False:
            docker_status = "🔧 Build Issue"
        
        # Notes based on performance
        notes_text = {
            'excellent': 'Excellent performance',
            'good': 'Good performance', 
            'needs_work': 'Needs attention'
        }.get(status, '')
        
        # Create table row
        row = f"| {emoji} **{lang}** | {build_time} | {analyze_time} | {features} | {makefile} | {docker_status} | {notes_text} |"
        table_rows.append(row)
    
    # Create complete table
    table_header = """| Language | Build Time | Analysis Time | Features | Makefile | Docker | Notes |
|----------|------------|---------------|----------|----------|--------|-------|"""
    
    return table_header + "\n" + "\n".join(table_rows)

def update_readme_status():
    """Update README.md with latest benchmark results"""
    
    # Load performance data
    performance_data = load_performance_data()
    
    if not performance_data:
        print("❌ No performance data available")
        return False
    
    # Generate new status table
    new_table = generate_status_table(performance_data)
    
    # Read current README
    readme_path = Path('README.md')
    if not readme_path.exists():
        print("❌ README.md not found")
        return False
    
    content = readme_path.read_text()
    
    # Find and replace the status table
    pattern = r'(## 📊 Implementation Status Overview\s*\n\n)(.*?)(\n\n### Status Legend|\n\n##|\n\n\*Build times)'
    
    def replacement(match):
        return match.group(1) + new_table + "\n" + match.group(3)
    
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    if new_content == content:
        print("⚠️ No status table found to update")
        return False
    
    # Add timestamp comment
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')
    new_content = new_content.replace(
        "*Build times measured on Apple Silicon M1",
        f"*Last updated: {timestamp} - Build times measured on GitHub Actions runner"
    )
    
    # Write updated README
    readme_path.write_text(new_content)
    print("✅ README.md status table updated successfully")
    return True

def main():
    """Main function."""
    success = update_readme_status()
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())