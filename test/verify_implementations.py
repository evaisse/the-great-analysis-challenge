#!/usr/bin/env python3
"""
Implementation Structure Verification Script

This script verifies that each chess engine implementation follows
the required project structure and contains all necessary files.
"""

import os
import json
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple
from importlib import import_module

# Ensure repository root is importable
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

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
        
        # Check path standards (Prevention Guideline 1)
        path_issues = check_meta_path_standards(data, meta_path.parent.name)
        result['errors'].extend(path_issues['errors'])
        result['warnings'].extend(path_issues['warnings'])
        
        # Validate JSON structure
        result['info'].append(f"Language: {data.get('language', 'unknown')}")
        result['info'].append(f"Version: {data.get('version', 'unknown')}")
        
    except json.JSONDecodeError as e:
        result['errors'].append(f"Invalid JSON format: {e}")
    except Exception as e:
        result['errors'].append(f"Error reading chess.meta: {e}")
    
    return result

def check_meta_path_standards(data: dict, impl_name: str) -> Dict[str, List[str]]:
    """Check chess.meta path standards (Prevention Guideline 1)."""
    result = {'errors': [], 'warnings': []}
    
    path_fields = ['build', 'run', 'analyze', 'test']
    
    for field in path_fields:
        if field in data:
            command = data[field]
            
            # Check for directory prefixes that indicate wrong working directory assumptions
            if f'cd {impl_name}' in command:
                result['errors'].append(f"{field}: Contains 'cd {impl_name}' - should use relative paths from implementation directory")
            
            # Check for hardcoded directory paths in commands
            if f'{impl_name}/' in command:
                result['warnings'].append(f"{field}: Contains '{impl_name}/' prefix - should use relative paths")
            
            # Check for absolute paths
            if command.startswith('/'):
                result['warnings'].append(f"{field}: Uses absolute path - should use relative paths")
            
            # Check for parent directory references that might indicate wrong working dir
            if '../' in command:
                result['warnings'].append(f"{field}: Contains '../' - verify working directory assumptions")
    
    return result

def check_package_dependencies(impl_dir: Path, language: str) -> Dict[str, List[str]]:
    """Check package manager dependencies (Prevention Guidelines 3 & 4)."""
    result = {'errors': [], 'warnings': [], 'info': []}
    
    if language.lower() == 'typescript' or language.lower() == 'javascript':
        return check_npm_dependencies(impl_dir)
    elif language.lower() == 'ruby':
        return check_ruby_dependencies(impl_dir)
    elif language.lower() == 'python':
        return check_python_dependencies(impl_dir)
    else:
        result['info'].append(f"No dependency checks implemented for {language}")
    
    return result

def check_npm_dependencies(impl_dir: Path) -> Dict[str, List[str]]:
    """Check NPM package.json for required scripts and dependencies."""
    result = {'errors': [], 'warnings': [], 'info': []}
    
    package_json_path = impl_dir / 'package.json'
    if not package_json_path.exists():
        result['errors'].append("Missing package.json file")
        return result
    
    try:
        with open(package_json_path) as f:
            package_data = json.load(f)
        
        # Check required scripts (Prevention Guideline 4)
        required_scripts = {'build', 'test', 'lint'}
        scripts = package_data.get('scripts', {})
        
        missing_scripts = required_scripts - set(scripts.keys())
        if missing_scripts:
            result['errors'].extend([f"Missing required npm script: {script}" for script in missing_scripts])
        
        # Check if scripts actually do something meaningful
        for script in required_scripts:
            if script in scripts:
                if scripts[script].strip() in ['', 'echo "No tests specified" && exit 1']:
                    result['warnings'].append(f"Script '{script}' appears to be placeholder - consider implementing")
        
        # Check for common tools used without being declared as dependencies
        all_commands = ' '.join(scripts.values())
        tools_to_check = {
            'tsc': 'typescript',
            'prettier': 'prettier', 
            'eslint': 'eslint',
            'jest': 'jest',
            'mocha': 'mocha'
        }
        
        dev_deps = package_data.get('devDependencies', {})
        dependencies = package_data.get('dependencies', {})
        all_deps = {**dev_deps, **dependencies}
        
        for tool, package in tools_to_check.items():
            if tool in all_commands and package not in all_deps:
                result['warnings'].append(f"Uses '{tool}' in scripts but '{package}' not in dependencies")
        
        result['info'].append(f"Found {len(scripts)} npm scripts")
        result['info'].append(f"Dependencies: {len(dependencies)}, DevDependencies: {len(dev_deps)}")
        
    except json.JSONDecodeError as e:
        result['errors'].append(f"Invalid package.json format: {e}")
    except Exception as e:
        result['errors'].append(f"Error reading package.json: {e}")
    
    return result

def check_ruby_dependencies(impl_dir: Path) -> Dict[str, List[str]]:
    """Check Ruby Gemfile for dependencies."""
    result = {'errors': [], 'warnings': [], 'info': []}
    
    gemfile_path = impl_dir / 'Gemfile'
    if gemfile_path.exists():
        try:
            content = gemfile_path.read_text()
            
            # Check for common development gems
            dev_gems = ['rubocop', 'rspec', 'bundler']
            for gem in dev_gems:
                if gem not in content:
                    result['info'].append(f"Consider adding '{gem}' gem for development")
            
            result['info'].append("Found Gemfile")
            
        except Exception as e:
            result['warnings'].append(f"Error reading Gemfile: {e}")
    else:
        result['warnings'].append("No Gemfile found - consider adding for dependency management")
    
    return result

def check_python_dependencies(impl_dir: Path) -> Dict[str, List[str]]:
    """Check Python requirements for dependencies."""
    result = {'errors': [], 'warnings': [], 'info': []}
    
    req_files = ['requirements.txt', 'requirements-dev.txt', 'pyproject.toml']
    found_req_file = False
    
    for req_file in req_files:
        req_path = impl_dir / req_file
        if req_path.exists():
            found_req_file = True
            result['info'].append(f"Found {req_file}")
            break
    
    if not found_req_file:
        result['warnings'].append("No requirements file found - consider adding for dependency management")
    
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
        
        # Check package dependencies (Prevention Guidelines 3 & 4)
        # Extract language from chess.meta data
        try:
            meta_content = meta_path.read_text()
            meta_data = json.loads(meta_content)
            language = meta_data.get('language', 'unknown')
        except:
            language = 'unknown'
        
        dependency_result = check_package_dependencies(impl_dir, language)
        result['dependencies'] = dependency_result
        result['summary']['errors'] += len(dependency_result['errors'])
        result['summary']['warnings'] += len(dependency_result['warnings'])
        result['summary']['info'] += len(dependency_result['info'])
    
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
    
    # Dependencies issues (Prevention Guidelines 3 & 4)
    deps = result.get('dependencies', {})
    if deps.get('errors'):
        print("\n❌ Dependency errors:")
        for error in deps['errors']:
            print(f"   - {error}")
    
    if deps.get('warnings'):
        print("\n⚠️  Dependency warnings:")
        for warning in deps['warnings']:
            print(f"   - {warning}")
    
    if deps.get('info'):
        print("\n📦 Dependency info:")
        for info in deps['info']:
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

def validate_unique_emojis(implementations: List[Path]) -> bool:
    """Ensure each implementation has a unique emoji in website metadata."""
    print("\n" + "="*50)
    print("🎨 EMOJI ASSIGNMENT CHECK")
    print("="*50)
    
    try:
        build_website = import_module('build_website')
        stats_data = build_website.load_language_statistics()
        language_metadata = build_website.get_language_metadata(stats_data)
    except Exception as exc:
        print(f"❌ Unable to load language metadata: {exc}")
        return False
    
    emoji_map: Dict[str, List[str]] = {}
    missing_languages: List[str] = []
    missing_emojis: List[str] = []
    
    for impl_dir in implementations:
        lang = impl_dir.name
        meta = language_metadata.get(lang)
        if not meta:
            missing_languages.append(lang)
            continue
        emoji = meta.get('emoji')
        if not emoji:
            missing_emojis.append(lang)
            continue
        emoji_map.setdefault(emoji, []).append(lang)
    
    duplicates = {emoji: langs for emoji, langs in emoji_map.items() if len(langs) > 1}
    check_passed = True
    
    if missing_languages:
        print("❌ Missing emoji metadata for implementations:")
        for lang in sorted(missing_languages):
            print(f"   - {lang}")
        check_passed = False
    
    if missing_emojis:
        print("❌ Emoji value not defined for implementations:")
        for lang in sorted(missing_emojis):
            print(f"   - {lang}")
        check_passed = False
    
    if duplicates:
        print("❌ Emoji collisions detected:")
        for emoji, langs in duplicates.items():
            joined = ', '.join(sorted(langs))
            print(f"   - {emoji} used by {joined}")
        check_passed = False
    
    if check_passed:
        print("✅ All implementations have unique emojis defined for the website.")
    return check_passed

def main():
    """Main verification function."""
    parser = argparse.ArgumentParser(
        description="Chess Engine Implementation Structure Verification",
        epilog="""
Examples:
  python3 verify_implementations.py
    Verify all implementations in the project
    
  python3 verify_implementations.py /path/to/implementations
    Verify implementations in custom directory

Verification Checks:
  Required Files:
    - Dockerfile      Docker container definition
    - Makefile        Build automation with required targets
    - chess.meta      JSON metadata file  
    - README.md       Implementation documentation

  Dockerfile Requirements:
    - FROM ubuntu:24.04 as base image
    - DEBIAN_FRONTEND=noninteractive environment variable
    - Proper WORKDIR and COPY instructions

  Makefile Requirements:
    - Required targets: all, build, test, analyze, clean, docker-build, docker-test, help
    - .PHONY declarations for non-file targets

  chess.meta Requirements:
    - Valid JSON format
    - Required fields: language, version, author, build, run, features, max_ai_depth
    - Recommended fields: analyze, test, estimated_perft4_ms
    - Expected features: perft, fen, ai, castling, en_passant, promotion

Status Classifications:
  🟢 Excellent - All files present, full compliance, no issues
  🟡 Good      - Minor warnings or missing optional fields  
  🔴 Needs Work - Missing required files or significant issues

Exit Codes:
  0 - All implementations passed verification
  1 - One or more implementations need work
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        "base_dir",
        nargs="?",
        help="Base directory containing implementations (default: project root)"
    )
    
    args = parser.parse_args()
    
    if args.base_dir:
        base_dir = Path(args.base_dir)
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
    
    emojis_ok = validate_unique_emojis(implementations)
    
    exit_code = 0
    if any(r['status'] == 'needs_work' for r in results):
        exit_code = 1
    if not emojis_ok:
        exit_code = 1
    
    if exit_code == 0:
        print("\n✅ All implementations passed verification and emoji check!")
    else:
        print("\n❌ Some checks failed. See details above.")
    sys.exit(exit_code)

if __name__ == '__main__':
    main()
