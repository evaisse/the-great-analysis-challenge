#!/usr/bin/env python3
"""
Check if language_statistics.yaml needs updating (older than one month).
This script can be run manually or as part of CI/CD.
"""

import sys
import yaml
from datetime import datetime, timedelta


def check_freshness():
    """Check if language statistics need updating."""
    stats_file = "language_statistics.yaml"
    
    try:
        with open(stats_file, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"❌ Error: {stats_file} not found")
        return 1
    except Exception as e:
        print(f"❌ Error loading {stats_file}: {e}")
        return 1
    
    metadata = data.get('metadata', {})
    last_updated_str = metadata.get('last_updated')
    
    if not last_updated_str:
        print("❌ Error: No last_updated date found in statistics")
        return 1
    
    try:
        last_updated = datetime.fromisoformat(last_updated_str)
        one_month_ago = datetime.now() - timedelta(days=30)
        days_old = (datetime.now() - last_updated).days
        
        print(f"📊 Language statistics status:")
        print(f"   Last updated: {last_updated_str}")
        print(f"   Days old: {days_old}")
        print(f"   TIOBE source: {metadata.get('tiobe_source', 'N/A')}")
        print(f"   GitHub source: {metadata.get('github_source', 'N/A')}")
        print()
        
        if last_updated < one_month_ago:
            print(f"⚠️  Statistics are outdated (older than 30 days)")
            print(f"   Please update {stats_file} with fresh data from:")
            print(f"   - {metadata.get('tiobe_source', 'https://www.tiobe.com/tiobe-index/')}")
            print(f"   - {metadata.get('github_source', 'https://github.com/EvanLi/Github-Ranking')}")
            return 2  # Exit code 2 indicates update needed
        else:
            print(f"✅ Statistics are fresh (less than 30 days old)")
            return 0
            
    except Exception as e:
        print(f"❌ Error parsing date: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(check_freshness())
