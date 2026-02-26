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
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple
from importlib import import_module

# Ensure repository root is importable
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

# Add scripts directory to path to import shared module
SCRIPTS_DIR = REPO_ROOT / 'scripts'
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from chess_metadata import get_metadata

# Required files for each implementation
REQUIRED_FILES = {
    'Dockerfile': 'Docker container definition',
    'Makefile': 'Build automation',
    'README.md': 'Implementation documentation',
}

# Required Makefile targets
REQUIRED_MAKEFILE_TARGETS = {
    'all', 'build', 'test', 'analyze', 'clean', 'docker-build', 'docker-test', 'help'
}

# Required metadata fields
REQUIRED_META_FIELDS = {
    'language', 'version', 'author', 'build', 'run', 'features', 'max_ai_depth'
}

# Optional but recommended metadata fields
RECOMMENDED_META_FIELDS = {
    'analyze', 'test', 'estimated_perft4_ms'
}

# Expected features in metadata
EXPECTED_FEATURES = {
    'perft', 'fen', 'ai', 'castling', 'en_passant', 'promotion'
}

HASKELL_STDLIB_PACKAGES = {
    'base', 'containers', 'array', 'time'
}

KOTLIN_STDLIB_COORDS = {
    'org.jetbrains.kotlin:kotlin-stdlib',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk7',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk8',
    'org.jetbrains.kotlin:kotlin-stdlib-common',
}

PYTHON_TOOLING_PACKAGES = {
    'mypy', 'pylint', 'flake8', 'black', 'bandit', 'pytest', 'coverage', 'ruff', 'isort'
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
    impl_name = dockerfile_path.parent.name
    expected_base = f"FROM ghcr.io/evaisse/tgac-{impl_name}-toolchain:latest"
    
    try:
        content = dockerfile_path.read_text()
        lines = content.splitlines()
        
        # Check for compact structure: MUST start with the specific toolchain image
        if not lines or not lines[0].startswith(expected_base):
            issues.append(f"Dockerfile MUST start with '{expected_base}'")
            
        # Check for essential labels
        if 'LABEL org.chess.language' not in content:
            issues.append("Dockerfile missing LABEL org.chess.language")
            
        # Check for external downloads (prevention check)
        if 'apt-get' in content or 'wget' in content or 'curl' in content:
            issues.append("Dockerfile contains external download commands (apt-get, wget, curl). Move these to toolchain image.")

    except Exception as e:
        issues.append(f"Error reading Dockerfile: {e}")
    
    return issues


def check_toolchain_presence(impl_dir: Path) -> List[str]:
    """Check for colocated toolchain definition."""
    issues = []
    toolchain_dockerfile = impl_dir / 'docker-images' / 'toolchain' / 'Dockerfile'
    
    if not toolchain_dockerfile.exists():
        issues.append(f"Missing toolchain definition at {toolchain_dockerfile.relative_to(impl_dir.parent.parent)}")
        
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

def validate_metadata(data: Dict, impl_name: str) -> Dict[str, List[str]]:
    """Validate combined metadata."""
    result = {
        'errors': [],
        'warnings': [],
        'info': []
    }
    
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
        try:
            depth_int = int(depth)
            if depth_int < 1 or depth_int > 10:
                result['warnings'].append(f"max_ai_depth should be between 1-10, got: {depth}")
        except:
            result['warnings'].append(f"max_ai_depth should be an integer, got: {depth}")
    
    # Check path standards
    path_issues = check_meta_path_standards(data, impl_name)
    result['errors'].extend(path_issues['errors'])
    result['warnings'].extend(path_issues['warnings'])
    
    # Info
    result['info'].append(f"Language: {data.get('language', 'unknown')}")
    result['info'].append(f"Version: {data.get('version', 'unknown')}")
    
    return result

def check_meta_path_standards(data: dict, impl_name: str) -> Dict[str, List[str]]:
    """Check path standards (Prevention Guideline 1)."""
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
            if isinstance(command, str) and command.startswith('/'):
                result['warnings'].append(f"{field}: Uses absolute path - should use relative paths")
            
            # Check for parent directory references that might indicate wrong working dir
            if isinstance(command, str) and '../' in command:
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

def check_stdlib_only(impl_dir: Path, language: str) -> Dict[str, List[str]]:
    """Best-effort guardrail: ensure runtime deps stay in the standard library."""
    result = {'errors': [], 'warnings': [], 'info': []}
    lang = language.lower()

    if lang in {'typescript', 'javascript', 'imba', 'rescript', 'elm'}:
        package_json_path = impl_dir / 'package.json'
        if not package_json_path.exists():
            result['info'].append("No package.json found")
            return result
        try:
            with open(package_json_path) as f:
                package_data = json.load(f)
            dependencies = package_data.get('dependencies', {}) or {}
            dev_dependencies = package_data.get('devDependencies', {}) or {}
            if dependencies:
                result['errors'].append(f"Runtime dependencies found: {', '.join(sorted(dependencies.keys()))}")
            if dev_dependencies:
                result['warnings'].append(f"Dev dependencies present: {', '.join(sorted(dev_dependencies.keys()))}")
        except Exception as e:
            result['warnings'].append(f"Unable to parse package.json: {e}")
        return result

    if lang == 'python':
        req_files = ['requirements.txt', 'requirements-dev.txt', 'requirements-dev.in']
        found = False
        for req_file in req_files:
            req_path = impl_dir / req_file
            if not req_path.exists():
                continue
            found = True
            packages = []
            for line in req_path.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                line = line.split(';', 1)[0].strip()
                name = re.split(r'[<=>~! ]', line, maxsplit=1)[0].strip()
                if name:
                    packages.append(name)
            if packages:
                non_tooling = [p for p in packages if not (p in PYTHON_TOOLING_PACKAGES or p.startswith('types-'))]
                if non_tooling:
                    result['errors'].append(f"Non-tooling requirements found: {', '.join(sorted(non_tooling))}")
                else:
                    result['warnings'].append(f"Tooling requirements present in {req_file}: {', '.join(sorted(packages))}")
        if not found:
            result['info'].append("No requirements files found")
        return result

    if lang == 'ruby':
        gemfile_path = impl_dir / 'Gemfile'
        if not gemfile_path.exists():
            result['info'].append("No Gemfile found")
            return result
        in_dev_group = False
        runtime_gems = []
        dev_gems = []
        for line in gemfile_path.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            if stripped.startswith('group ') and ('development' in stripped or 'test' in stripped):
                in_dev_group = True
                continue
            if stripped == 'end':
                in_dev_group = False
                continue
            match = re.search(r'gem\s+[\'"]([^\'"]+)[\'"]', stripped)
            if match:
                gem_name = match.group(1)
                if in_dev_group:
                    dev_gems.append(gem_name)
                else:
                    runtime_gems.append(gem_name)
        if runtime_gems:
            result['errors'].append(f"Runtime gems found: {', '.join(sorted(runtime_gems))}")
        if dev_gems:
            result['warnings'].append(f"Dev/test gems present: {', '.join(sorted(dev_gems))}")
        return result

    if lang == 'dart':
        pubspec_path = impl_dir / 'pubspec.yaml'
        if not pubspec_path.exists():
            result['info'].append("No pubspec.yaml found")
            return result
        deps = []
        dev_deps = []
        current = None
        for line in pubspec_path.read_text().splitlines():
            raw = line.rstrip()
            stripped = raw.strip()
            if not stripped or stripped.startswith('#'):
                continue
            if not raw.startswith(' ') and stripped.endswith(':'):
                key = stripped[:-1]
                if key in {'dependencies', 'dev_dependencies'}:
                    current = key
                else:
                    current = None
                continue
            if current and raw.startswith('  ') and ':' in stripped:
                name = stripped.split(':', 1)[0].strip()
                if current == 'dependencies':
                    deps.append(name)
                else:
                    dev_deps.append(name)
        deps = [d for d in deps if d != 'sdk']
        if deps:
            result['errors'].append(f"Dart dependencies found: {', '.join(sorted(deps))}")
        if dev_deps:
            result['warnings'].append(f"Dart dev_dependencies present: {', '.join(sorted(dev_deps))}")
        return result

    if lang == 'rust':
        cargo_path = impl_dir / 'Cargo.toml'
        if not cargo_path.exists():
            result['info'].append("No Cargo.toml found")
            return result
        current = None
        deps = {'dependencies': [], 'dev-dependencies': [], 'build-dependencies': []}
        for line in cargo_path.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            if stripped.startswith('[') and stripped.endswith(']'):
                section = stripped.strip('[]')
                current = section if section in deps else None
                continue
            if current and '=' in stripped:
                name = stripped.split('=', 1)[0].strip()
                if name:
                    deps[current].append(name)
        if deps['dependencies']:
            result['errors'].append(f"Rust dependencies found: {', '.join(sorted(deps['dependencies']))}")
        dev = deps['dev-dependencies'] + deps['build-dependencies']
        if dev:
            result['warnings'].append(f"Rust dev/build dependencies present: {', '.join(sorted(dev))}")
        return result

    if lang == 'go':
        gomod_path = impl_dir / 'go.mod'
        if not gomod_path.exists():
            result['info'].append("No go.mod found")
            return result
        requires = []
        in_block = False
        for line in gomod_path.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith('//'):
                continue
            if stripped.startswith('require ('):
                in_block = True
                continue
            if in_block:
                if stripped == ')':
                    in_block = False
                    continue
                requires.append(stripped.split()[0])
                continue
            if stripped.startswith('require '):
                requires.append(stripped[len('require '):].split()[0])
        if requires:
            result['errors'].append(f"Go module dependencies found: {', '.join(sorted(requires))}")
        return result

    if lang == 'php':
        composer_path = impl_dir / 'composer.json'
        if not composer_path.exists():
            result['info'].append("No composer.json found")
            return result
        try:
            with open(composer_path) as f:
                data = json.load(f)
            require = data.get('require', {}) or {}
            require_dev = data.get('require-dev', {}) or {}
            runtime = [k for k in require.keys() if k != 'php' and not k.startswith('ext-')]
            if runtime:
                result['errors'].append(f"Composer runtime dependencies found: {', '.join(sorted(runtime))}")
            if require_dev:
                result['warnings'].append(f"Composer dev dependencies present: {', '.join(sorted(require_dev.keys()))}")
        except Exception as e:
            result['warnings'].append(f"Unable to parse composer.json: {e}")
        return result

    if lang == 'kotlin':
        gradle_paths = [impl_dir / 'build.gradle.kts', impl_dir / 'build.gradle']
        gradle_path = next((p for p in gradle_paths if p.exists()), None)
        if not gradle_path:
            result['info'].append("No Gradle build file found")
            return result
        runtime = []
        tests = []
        in_block = False
        brace_depth = 0
        for line in gradle_path.read_text().splitlines():
            stripped = line.strip()
            if stripped.startswith('dependencies'):
                if '{' in stripped:
                    in_block = True
                    brace_depth += stripped.count('{') - stripped.count('}')
                continue
            if in_block:
                brace_depth += stripped.count('{') - stripped.count('}')
                if brace_depth <= 0:
                    in_block = False
                    continue
                if stripped.startswith(('implementation', 'api', 'compileOnly', 'runtimeOnly')):
                    runtime.append(stripped)
                elif stripped.startswith(('testImplementation', 'testCompileOnly', 'testRuntimeOnly')):
                    tests.append(stripped)
        filtered_runtime = []
        for entry in runtime:
            if any(coord in entry for coord in KOTLIN_STDLIB_COORDS) or 'kotlin("stdlib' in entry:
                continue
            filtered_runtime.append(entry)
        if filtered_runtime:
            result['errors'].append("Kotlin runtime dependencies found: " + "; ".join(filtered_runtime))
        if tests:
            result['warnings'].append("Kotlin test dependencies present: " + "; ".join(tests))
        return result

    if lang == 'swift':
        package_path = impl_dir / 'Package.swift'
        if not package_path.exists():
            result['info'].append("No Package.swift found")
            return result
        packages = []
        for line in package_path.read_text().splitlines():
            stripped = line.strip()
            if '.package(' in stripped:
                packages.append(stripped)
        if packages:
            result['errors'].append("Swift package dependencies found: " + "; ".join(packages))
        return result

    if lang == 'haskell':
        cabal_path = impl_dir / 'chess.cabal'
        if not cabal_path.exists():
            result['info'].append("No .cabal file found")
            return result
        deps = []
        collecting = False
        for line in cabal_path.read_text().splitlines():
            if line.strip().startswith('build-depends:'):
                collecting = True
                rest = line.split(':', 1)[1]
                deps.extend([d.strip() for d in rest.split(',') if d.strip()])
                continue
            if collecting:
                if line.strip() == '' or not line.startswith(' '):
                    collecting = False
                    continue
                deps.extend([d.strip() for d in line.split(',') if d.strip()])
        packages = []
        for dep in deps:
            name = dep.split()[0].strip()
            if name:
                packages.append(name)
        non_std = [p for p in packages if p not in HASKELL_STDLIB_PACKAGES]
        if non_std:
            result['errors'].append(f"Haskell dependencies found: {', '.join(sorted(set(non_std)))}")
        return result

    result['info'].append(f"No stdlib-only checks implemented for {language}")
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
        
        # Check required scripts
        required_scripts = {'build', 'test', 'lint'}
        scripts = package_data.get('scripts', {})
        
        missing_scripts = required_scripts - set(scripts.keys())
        if missing_scripts:
            result['errors'].extend([f"Missing required npm script: {script}" for script in missing_scripts])
        
        result['info'].append(f"Found {len(scripts)} npm scripts")
        
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
        result['info'].append("Found Gemfile")
    else:
        result['warnings'].append("No Gemfile found")
    return result

def check_python_dependencies(impl_dir: Path) -> Dict[str, List[str]]:
    """Check Python requirements for dependencies."""
    result = {'errors': [], 'warnings': [], 'info': []}
    req_files = ['requirements.txt', 'requirements-dev.txt', 'pyproject.toml']
    found_req_file = False
    for req_file in req_files:
        if (impl_dir / req_file).exists():
            found_req_file = True
            result['info'].append(f"Found {req_file}")
            break
    if not found_req_file:
        result['warnings'].append("No requirements file found")
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
    
    # Check toolchain
    toolchain_issues = check_toolchain_presence(impl_dir)
    result['toolchain'] = {'issues': toolchain_issues}
    result['summary']['errors'] += len(toolchain_issues)

    # Get metadata from Dockerfile labels
    metadata = get_metadata(str(impl_dir))
    
    if not metadata:
        missing_files.append('Dockerfile labels (org.chess.*)')
    
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
    
    if metadata:
        meta_result = validate_metadata(metadata, impl_name)
        result['chess_meta'] = meta_result
        result['summary']['errors'] += len(meta_result['errors'])
        result['summary']['warnings'] += len(meta_result['warnings'])
        result['summary']['info'] += len(meta_result['info'])
        
        # Check package dependencies
        language = metadata.get('language', 'unknown')
        dependency_result = check_package_dependencies(impl_dir, language)
        result['dependencies'] = dependency_result
        result['summary']['errors'] += len(dependency_result['errors'])
        result['summary']['warnings'] += len(dependency_result['warnings'])
        result['summary']['info'] += len(dependency_result['info'])

        # Enforce stdlib-only rule (best-effort)
        stdlib_result = check_stdlib_only(impl_dir, language)
        result['stdlib_only'] = stdlib_result
        result['summary']['errors'] += len(stdlib_result['errors'])
        result['summary']['warnings'] += len(stdlib_result['warnings'])
        result['summary']['info'] += len(stdlib_result['info'])

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
    
    status_emoji = {
        'excellent': '🟢',
        'good': '🟡', 
        'needs_work': '🔴',
        'unknown': '⚪'
    }
    
    print(f"\n{status_emoji[status]} **{name}** ({status})")
    print("=" * (len(name) + 20))
    
    if result['files']['missing']:
        print("❌ Missing files:")
        for file in result['files']['missing']:
            print(f"   - {file}")
    
    if result['files']['found']:
        print("✅ Found files:")
        for file in result['files']['found']:
            print(f"   - {file}")
    
    if result['dockerfile'].get('issues'):
        print("\n⚠️  Dockerfile issues:")
        for issue in result['dockerfile']['issues']:
            print(f"   - {issue}")
    
    if result['toolchain'].get('issues'):
        print("\n❌ Toolchain issues:")
        for issue in result['toolchain']['issues']:
            print(f"   - {issue}")
    
    if result['makefile'].get('missing_targets'):
        print("\n❌ Missing Makefile targets:")
        for target in result['makefile']['missing_targets']:
            print(f"   - {target}")
    
    meta = result.get('chess_meta', {})
    if meta.get('errors'):
        print("\n❌ Metadata errors:")
        for error in meta['errors']:
            print(f"   - {error}")
    
    if meta.get('warnings'):
        print("\n⚠️  Metadata warnings:")
        for warning in meta['warnings']:
            print(f"   - {warning}")
    
    if meta.get('info'):
        print("\n📝 Metadata info:")
        for info in meta['info']:
            print(f"   - {info}")

    deps = result.get('dependencies', {})
    if deps.get('errors'):
        print("\n❌ Dependency check errors:")
        for error in deps['errors']:
            print(f"   - {error}")
    if deps.get('warnings'):
        print("\n⚠️  Dependency check warnings:")
        for warning in deps['warnings']:
            print(f"   - {warning}")
    if deps.get('info'):
        print("\n📝 Dependency check info:")
        for info in deps['info']:
            print(f"   - {info}")

    stdlib_result = result.get('stdlib_only', {})
    if stdlib_result.get('errors'):
        print("\n❌ Standard library rule violations:")
        for error in stdlib_result['errors']:
            print(f"   - {error}")
    if stdlib_result.get('warnings'):
        print("\n⚠️  Standard library rule warnings:")
        for warning in stdlib_result['warnings']:
            print(f"   - {warning}")
    if stdlib_result.get('info'):
        print("\n📝 Standard library rule info:")
        for info in stdlib_result['info']:
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

def main():
    parser = argparse.ArgumentParser(description="Verify Chess Engine Implementation")
    parser.add_argument("base_dir", nargs="?", help="Base directory")
    parser.add_argument("--implementation", "-i", help="Verify only one")
    args = parser.parse_args()
    
    base_dir = Path(args.base_dir) if args.base_dir else Path(os.getcwd())
    implementations = find_implementations(base_dir)
    
    if args.implementation:
        implementations = [i for i in implementations if i.name == args.implementation]
    
    results = []
    for impl_dir in sorted(implementations):
        result = verify_implementation(impl_dir)
        results.append(result)
        print_implementation_report(result)
    
    print_summary_report(results)
    
    if any(r['status'] == 'needs_work' for r in results):
        sys.exit(1)
    sys.exit(0)

if __name__ == '__main__':
    main()
