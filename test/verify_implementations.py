#!/usr/bin/env python3
"""
Implementation Structure Verification Script

This script verifies that each chess engine implementation follows
the required project structure and contains all necessary files.
"""

import os
import json
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

# Required files for each implementation
REQUIRED_FILES = {
    'Dockerfile': 'Docker container definition',
    'Makefile': 'Build automation',
    'chess.meta': 'Metadata file (JSON)',
    'README.md': 'Implementation documentation',
}

# Required Makefile targets
REQUIRED_MAKEFILE_TARGETS = {
    'all', 'build', 'test', 'analyze', 'clean', 'docker-build', 'docker-test', 'help'
}

# Required chess.meta fields
REQUIRED_META_FIELDS = {
    'language', 'version', 'author', 'build', 'run', 'features', 'max_ai_depth'
}

# Optional but recommended chess.meta fields
RECOMMENDED_META_FIELDS = {
    'analyze', 'test', 'estimated_perft4_ms'
}

# Expected features in chess.meta
EXPECTED_FEATURES = {
    'perft', 'fen', 'ai', 'castling', 'en_passant', 'promotion'
}

def find_implementations(base_dir: Path) -> List[Path]:
    """Find all implementation directories."""
    implementations_dir = base_dir / 'implementations'
    if not implementations_dir.exists():
        print(f"❌ Implementations directory not found: {implementations_dir}")
        return []
    
    return [d for d in implementations_dir.iterdir() if d.is_dir()]

def check_required_files(impl_dir: Path) -> Tuple[List[str], List[str]]:
    """Check for required files in implementation directory."""
    found_files = []
    missing_files = []
    
    for required_file, description in REQUIRED_FILES.items():
        file_path = impl_dir / required_file
        if file_path.exists():
            found_files.append(required_file)
        else:
            missing_files.append(f"{required_file} ({description})")
    
    return found_files, missing_files

def check_dockerfile_format(dockerfile_path: Path) -> List[str]:
    """Check Dockerfile format and requirements."""
    issues = []
    
    try:
        content = dockerfile_path.read_text()
        
        # Check for ubuntu:24.04 base image
        if 'FROM ubuntu:24.04' not in content:
            issues.append("Dockerfile should use 'FROM ubuntu:24.04' as base image")
        
        # Check for DEBIAN_FRONTEND=noninteractive
        if 'DEBIAN_FRONTEND=noninteractive' not in content:
            issues.append("Dockerfile should set DEBIAN_FRONTEND=noninteractive")
        
        # Check for basic structure
        if 'WORKDIR' not in content:
            issues.append("Dockerfile should have a WORKDIR instruction")
        
        if 'COPY' not in content:
            issues.append("Dockerfile should copy source files")
            
    except Exception as e:
        issues.append(f"Error reading Dockerfile: {e}")
    
    return issues

def check_makefile_targets(makefile_path: Path) -> Tuple[Set[str], Set[str]]:
    """Check Makefile for required targets."""
    found_targets = set()
    
    try:
        content = makefile_path.read_text()
        
        # Simple target detection - look for lines starting with target names followed by :
        for line in content.split('\n'):
            line = line.strip()
            if ':' in line and not line.startswith('#') and not line.startswith('\t'):
                target = line.split(':')[0].strip()
                found_targets.add(target)
        
        # Check for .PHONY declaration
        if '.PHONY' not in content:
            found_targets.add('_missing_phony')
            
    except Exception as e:
        found_targets.add(f'_error_{e}')
    
    missing_targets = REQUIRED_MAKEFILE_TARGETS - found_targets
    return found_targets, missing_targets

def check_chess_meta(meta_path: Path) -> Dict[str, List[str]]:
    """Check chess.meta file format and content."""
    result = {
        'errors': [],
        'warnings': [],
        'info': []
    }
    
    try:
        content = meta_path.read_text()
        data = json.loads(content)
        
        # Check required fields
        missing_required = REQUIRED_META_FIELDS - set(data.keys())
        if missing_required:
            result['errors'].extend([f"Missing required field: {field}" for field in missing_required])
        
        # Check recommended fields
        missing_recommended = RECOMMENDED_META_FIELDS - set(data.keys())
        if missing_recommended:
            result['warnings'].extend([f"Missing recommended field: {field}" for field in missing_recommended])
        
        # Check features
        if 'features' in data:
            features = set(data['features'])
            missing_features = EXPECTED_FEATURES - features
            if missing_features:
                result['warnings'].extend([f"Missing feature: {feature}" for feature in missing_features])
            
            extra_features = features - EXPECTED_FEATURES
            if extra_features:
                result['info'].extend([f"Extra feature: {feature}" for feature in extra_features])
        
        # Check AI depth
        if 'max_ai_depth' in data:
            depth = data['max_ai_depth']
            if not isinstance(depth, int) or depth < 1 or depth > 10:
                result['warnings'].append(f"max_ai_depth should be between 1-10, got: {depth}")
        
        # Validate JSON structure
        result['info'].append(f"Language: {data.get('language', 'unknown')}")
        result['info'].append(f"Version: {data.get('version', 'unknown')}")
        
    except json.JSONDecodeError as e:
        result['errors'].append(f"Invalid JSON format: {e}")
    except Exception as e:
        result['errors'].append(f"Error reading chess.meta: {e}")
    
    return result

def verify_implementation(impl_dir: Path) -> Dict:
    """Verify a single implementation."""
    impl_name = impl_dir.name
    result = {
        'name': impl_name,
        'path': str(impl_dir),
        'status': 'unknown',
        'files': {},
        'dockerfile': {},
        'makefile': {},
        'chess_meta': {},
        'summary': {'errors': 0, 'warnings': 0, 'info': 0}
    }
    
    # Check required files
    found_files, missing_files = check_required_files(impl_dir)
    result['files'] = {
        'found': found_files,
        'missing': missing_files
    }
    
    if missing_files:
        result['summary']['errors'] += len(missing_files)
    
    # Check Dockerfile if it exists
    dockerfile_path = impl_dir / 'Dockerfile'
    if dockerfile_path.exists():
        dockerfile_issues = check_dockerfile_format(dockerfile_path)
        result['dockerfile'] = {
            'issues': dockerfile_issues
        }
        result['summary']['warnings'] += len(dockerfile_issues)
    
    # Check Makefile if it exists
    makefile_path = impl_dir / 'Makefile'
    if makefile_path.exists():
        found_targets, missing_targets = check_makefile_targets(makefile_path)
        result['makefile'] = {
            'found_targets': list(found_targets),
            'missing_targets': list(missing_targets)
        }
        result['summary']['errors'] += len(missing_targets)
    
    # Check chess.meta if it exists
    meta_path = impl_dir / 'chess.meta'
    if meta_path.exists():
        meta_result = check_chess_meta(meta_path)
        result['chess_meta'] = meta_result
        result['summary']['errors'] += len(meta_result['errors'])
        result['summary']['warnings'] += len(meta_result['warnings'])
        result['summary']['info'] += len(meta_result['info'])
    
    # Determine overall status
    if result['summary']['errors'] == 0:
        if result['summary']['warnings'] == 0:
            result['status'] = 'excellent'
        else:
            result['status'] = 'good'
    else:
        result['status'] = 'needs_work'
    
    return result

def print_implementation_report(result: Dict):
    """Print a detailed report for a single implementation."""
    name = result['name']
    status = result['status']
    
    # Status emoji
    status_emoji = {
        'excellent': '🟢',
        'good': '🟡', 
        'needs_work': '🔴',
        'unknown': '⚪'
    }
    
    print(f"\n{status_emoji[status]} **{name}** ({status})")
    print("=" * (len(name) + 20))
    
    # Files check
    if result['files']['missing']:
        print("❌ Missing files:")
        for file in result['files']['missing']:
            print(f"   - {file}")
    
    if result['files']['found']:
        print("✅ Found files:")
        for file in result['files']['found']:
            print(f"   - {file}")
    
    # Dockerfile issues
    if result['dockerfile'].get('issues'):
        print("\n⚠️  Dockerfile issues:")
        for issue in result['dockerfile']['issues']:
            print(f"   - {issue}")
    
    # Makefile issues
    if result['makefile'].get('missing_targets'):
        print("\n❌ Missing Makefile targets:")
        for target in result['makefile']['missing_targets']:
            print(f"   - {target}")
    
    # Chess.meta issues
    meta = result['chess_meta']
    if meta.get('errors'):
        print("\n❌ Chess.meta errors:")
        for error in meta['errors']:
            print(f"   - {error}")
    
    if meta.get('warnings'):
        print("\n⚠️  Chess.meta warnings:")
        for warning in meta['warnings']:
            print(f"   - {warning}")
    
    if meta.get('info'):
        print("\n📝 Chess.meta info:")
        for info in meta['info']:
            print(f"   - {info}")

def print_summary_report(results: List[Dict]):
    """Print overall summary report."""
    total = len(results)
    excellent = sum(1 for r in results if r['status'] == 'excellent')
    good = sum(1 for r in results if r['status'] == 'good')
    needs_work = sum(1 for r in results if r['status'] == 'needs_work')
    
    print(f"\n" + "="*50)
    print("📊 OVERALL SUMMARY")
    print("="*50)
    print(f"Total implementations: {total}")
    print(f"🟢 Excellent: {excellent}")
    print(f"🟡 Good: {good}")
    print(f"🔴 Needs work: {needs_work}")
    
    if needs_work > 0:
        print(f"\n🔧 Implementations needing attention:")
        for result in results:
            if result['status'] == 'needs_work':
                print(f"   - {result['name']} ({result['summary']['errors']} errors, {result['summary']['warnings']} warnings)")

def main():
    """Main verification function."""
    if len(sys.argv) > 1:
        base_dir = Path(sys.argv[1])
    else:
        base_dir = Path(__file__).parent.parent
    
    print("🔍 Chess Engine Implementation Verification")
    print("=" * 50)
    print(f"Base directory: {base_dir}")
    
    implementations = find_implementations(base_dir)
    if not implementations:
        print("❌ No implementations found!")
        sys.exit(1)
    
    print(f"Found {len(implementations)} implementations")
    
    results = []
    for impl_dir in sorted(implementations):
        result = verify_implementation(impl_dir)
        results.append(result)
        print_implementation_report(result)
    
    print_summary_report(results)
    
    # Exit with error code if any implementation needs work
    if any(r['status'] == 'needs_work' for r in results):
        sys.exit(1)
    else:
        print("\n✅ All implementations passed verification!")
        sys.exit(0)

if __name__ == '__main__':
    main()