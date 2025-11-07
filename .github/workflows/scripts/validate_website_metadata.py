#!/usr/bin/env python3
"""
Validate that all implementations have required metadata in build_website.py.
This ensures each language has an emoji, website URL, and other display metadata.
"""

import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Set


def get_language_metadata_from_file() -> Dict[str, Dict]:
    """
    Extract language metadata dictionary from build_website.py.
    Returns the metadata dictionary.
    """
    # Read build_website.py and extract the language metadata
    build_website_path = Path("build_website.py")
    
    if not build_website_path.exists():
        print(f"❌ build_website.py not found at {build_website_path}")
        return {}
    
    try:
        # Import the function dynamically
        import importlib.util
        spec = importlib.util.spec_from_file_location("build_website", build_website_path)
        if spec is None or spec.loader is None:
            print(f"❌ Could not load build_website.py module spec")
            return {}
            
        build_website = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(build_website)
        
        # Get the metadata
        return build_website.get_language_metadata()
    except Exception as e:
        print(f"❌ Error importing build_website.py: {e}")
        print(f"   Make sure the file has valid Python syntax and no missing dependencies")
        return {}


def get_implementations() -> Set[str]:
    """Get list of all implementation directories."""
    impl_dir = Path("implementations")
    
    if not impl_dir.exists():
        print(f"❌ Implementations directory not found: {impl_dir}")
        return set()
    
    implementations = set()
    for item in impl_dir.iterdir():
        if item.is_dir() and not item.name.startswith('.'):
            implementations.add(item.name.lower())
    
    return implementations


def validate_metadata_completeness() -> Tuple[bool, List[str]]:
    """
    Validate that all implementations have complete metadata.
    
    Returns:
        Tuple of (all_valid, list of issues)
    """
    issues = []
    
    # Get implementations and metadata
    implementations = get_implementations()
    language_metadata = get_language_metadata_from_file()
    
    if not implementations:
        issues.append("No implementations found in implementations/ directory")
        return False, issues
    
    if not language_metadata:
        issues.append("Could not load language metadata from build_website.py")
        return False, issues
    
    print(f"Found {len(implementations)} implementation(s)")
    print(f"Found metadata for {len(language_metadata)} language(s)")
    print()
    
    # Check each implementation has metadata
    missing_metadata = []
    incomplete_metadata = []
    
    required_fields = {'emoji', 'website', 'tiobe_rank', 'github_stars'}
    
    for impl in sorted(implementations):
        if impl not in language_metadata:
            missing_metadata.append(impl)
            issues.append(f"Missing metadata for '{impl}' in build_website.py")
        else:
            # Check metadata completeness
            meta = language_metadata[impl]
            missing_fields = required_fields - set(meta.keys())
            
            if missing_fields:
                incomplete_metadata.append(impl)
                issues.append(f"Incomplete metadata for '{impl}': missing {missing_fields}")
            
            # Validate field values
            if 'emoji' in meta and not meta['emoji']:
                issues.append(f"Empty emoji for '{impl}'")
            
            if 'website' in meta:
                if not meta['website']:
                    issues.append(f"Empty website URL for '{impl}'")
                elif not meta['website'].startswith('http'):
                    issues.append(f"Invalid website URL for '{impl}': {meta['website']}")
    
    # Check for metadata without implementations (orphaned metadata)
    orphaned_metadata = set(language_metadata.keys()) - implementations
    if orphaned_metadata:
        for lang in sorted(orphaned_metadata):
            issues.append(f"Metadata exists for '{lang}' but no implementation found")
    
    all_valid = len(issues) == 0
    return all_valid, issues


def validate_website_metadata() -> int:
    """
    Main validation function.
    
    Returns:
        Exit code (0 for success, 1 for failures)
    """
    print("=" * 60)
    print("Validating Website Metadata Completeness")
    print("=" * 60)
    print()
    
    all_valid, issues = validate_metadata_completeness()
    
    if all_valid:
        print("✅ All implementations have complete metadata!")
        return 0
    else:
        print(f"❌ Found {len(issues)} issue(s):")
        print()
        for issue in issues:
            print(f"  - {issue}")
        print()
        print("Please update build_website.py to add missing metadata.")
        print("Each language needs: emoji, website, tiobe_rank, github_stars")
        return 1


def main(args):
    """Main function for validate-website-metadata command."""
    return validate_website_metadata()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Validate that all implementations have metadata in build_website.py'
    )
    args = parser.parse_args()
    
    sys.exit(main(args))
