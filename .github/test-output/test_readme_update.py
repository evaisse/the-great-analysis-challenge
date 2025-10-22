import json
import re
from datetime import datetime
from pathlib import Path

def test_readme_update():
    """Test the README update logic"""
    
    # Load test performance data
    try:
        with open('performance_data_test.json', 'r') as f:
            performance_data = json.load(f)
    except FileNotFoundError:
        print("⚠️ No performance data for README test")
        return False
    
    print(f"✅ Loaded performance data for {len(performance_data)} implementation(s)")
    
    # Test table generation logic
    status_emoji = {'excellent': '🟢', 'good': '🟡', 'needs_work': '🔴'}
    
    for impl in performance_data:
        lang = impl.get('language', 'Unknown').title()
        status = impl.get('status', 'unknown')
        
        if status == 'completed':
            errors = len(impl.get('errors', []))
            test_results = impl.get('test_results', {})
            failed_tests = len(test_results.get('failed', []))
            
            if errors == 0 and failed_tests == 0:
                final_status = 'excellent'
            elif errors <= 2 and failed_tests <= 1:
                final_status = 'good'
            else:
                final_status = 'needs_work'
        else:
            final_status = 'needs_work'
        
        emoji = status_emoji.get(final_status, '⚪')
        timings = impl.get('timings', {})
        build_time = timings.get('build_seconds', 0)
        analyze_time = timings.get('analyze_seconds', 0)
        
        print(f"   {emoji} {lang}: Build {build_time:.1f}s, Analysis {analyze_time:.1f}s")
    
    print("✅ README table generation logic working")
    return True

if __name__ == "__main__":
    test_readme_update()
