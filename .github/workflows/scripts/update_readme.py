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
from typing import Dict, List, Any, Optional

# Add scripts directory to path to import shared module
SCRIPTS_DIR = Path(__file__).resolve().parents[3] / "scripts"
if os.path.exists(SCRIPTS_DIR):
    import sys
    sys.path.insert(0, str(SCRIPTS_DIR))
    try:
        from chess_metadata import get_metadata
        from token_metrics import (
            TOKEN_METRIC_VERSION,
            collect_impl_metrics_from_metadata,
            parse_source_exts,
        )
    except ImportError:
        TOKEN_METRIC_VERSION = "tokens-v2"
        def get_metadata(impl_dir): return {}
        def collect_impl_metrics_from_metadata(impl_path, metadata): raise RuntimeError("token metrics unavailable")
        def parse_source_exts(raw_value): return []
else:
    TOKEN_METRIC_VERSION = "tokens-v2"
    def get_metadata(impl_dir): return {}
    def collect_impl_metrics_from_metadata(impl_path, metadata): raise RuntimeError("token metrics unavailable")
    def parse_source_exts(raw_value): return []

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
    'nim': '🦊',
    'php': '🐘',
    'rescript': '🧠',
    'ruby': '❤️',
    'rust': '🦀',
    'swift': '🐦',
    'typescript': '📘',
    'zig': '⚡'
}

GENERATED_SEGMENTS = (
    'dist/',
    'build/',
    'target/',
    'lib/es6/',
    '.build/',
    'zig-out/',
    '__pycache__/',
    'vendor/',
)

EXCLUDED_SEGMENTS = (
    '/test/',
    'test/',
)

FEATURE_CATALOG: List[str] = [
    "perft",
    "fen",
    "ai",
    "castling",
    "en_passant",
    "promotion",
    "pgn",
    "uci",
    "chess960",
]

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

def resolve_tokens_count(impl_data: Dict[str, Any], impl_path: str, meta: Dict[str, Any], language: str) -> Optional[int]:
    """Resolve TOKENS from benchmark report; fallback to local computation (non-blocking)."""
    metrics = impl_data.get("metrics", {})
    tokens_count = metrics.get("tokens_count") if isinstance(metrics, dict) else None
    metric_version = metrics.get("metric_version") if isinstance(metrics, dict) else None

    if isinstance(tokens_count, int) and tokens_count >= 0:
        if metric_version and metric_version != TOKEN_METRIC_VERSION:
            print(
                f"⚠️ {language}: metric version is {metric_version}, expected {TOKEN_METRIC_VERSION}. "
                "Using reported value anyway."
            )
        return tokens_count

    try:
        local_metrics = collect_impl_metrics_from_metadata(Path(impl_path), meta)
        local_tokens = local_metrics.get("tokens_count")
        if isinstance(local_tokens, int) and local_tokens >= 0:
            print(f"⚠️ {language}: missing report TOKENS, using local fallback ({TOKEN_METRIC_VERSION})")
            return local_tokens
    except Exception as exc:
        print(f"⚠️ {language}: could not compute TOKENS fallback: {exc}")

    return None

def _normalize_relpath(path: str) -> str:
    """Normalize a relative path for Markdown links."""
    return path.replace('\\', '/').lstrip('./')

def _is_generated_or_excluded_path(rel_path: str) -> bool:
    """True for generated/build/test paths we should avoid as entrypoint targets."""
    lowered = _normalize_relpath(rel_path).lower()
    return any(segment in lowered for segment in GENERATED_SEGMENTS + EXCLUDED_SEGMENTS)

def _entrypoint_score(rel_path: str) -> int:
    """Score a candidate entrypoint path (higher is better)."""
    path = _normalize_relpath(rel_path)
    lowered = path.lower()
    base = os.path.basename(lowered)

    score = 0
    if lowered.startswith('src/'):
        score += 50
    elif lowered.startswith('bin/'):
        score += 35
    elif lowered.startswith('lib/'):
        score += 20

    if re.search(r'(^|/)(main|chess|chess_engine|chessengine)\.[^/]+$', lowered):
        score += 35
    if 'chess_engine' in lowered or 'chessengine' in lowered:
        score += 25
    elif 'chess' in base:
        score += 15
    elif 'main' in base:
        score += 10

    if _is_generated_or_excluded_path(lowered):
        score -= 100

    # Favor shallower paths when score is equivalent.
    score -= lowered.count('/') // 2
    return score

def _extract_candidates_from_command(command: str, impl_path: str, extensions: List[str]) -> List[str]:
    """Extract source-like file candidates from metadata command strings."""
    if not command or not extensions:
        return []

    # Capture tokens that look like paths ending with a language extension.
    exts_pattern = '|'.join(re.escape(ext) for ext in extensions)
    token_pattern = re.compile(rf'([A-Za-z0-9_./*+-]+(?:{exts_pattern}))')

    results: List[str] = []
    seen = set()
    for match in token_pattern.finditer(command):
        raw = match.group(1).strip('\'"`()[]{};,')
        if not raw:
            continue

        if '*' in raw:
            expanded = glob.glob(os.path.join(impl_path, raw), recursive=True)
            for path in expanded:
                if os.path.isfile(path):
                    rel = _normalize_relpath(os.path.relpath(path, impl_path))
                    if rel not in seen:
                        seen.add(rel)
                        results.append(rel)
            continue

        abs_candidate = os.path.join(impl_path, raw)
        if os.path.isfile(abs_candidate):
            rel = _normalize_relpath(raw)
            if rel not in seen:
                seen.add(rel)
                results.append(rel)

    return results

def resolve_entrypoint_file(impl_path: str, language: str, meta: Dict[str, Any]) -> Optional[str]:
    """Resolve the best source entrypoint file for a language implementation."""
    extensions = parse_source_exts(meta.get("source_exts"))
    if not extensions:
        print(f"⚠️ {language}: metadata source_exts missing or invalid; cannot link TOKENS to entrypoint")
        return None

    candidates: List[str] = []
    seen = set()

    # First pass: infer from metadata commands.
    for key in ('build', 'run', 'test', 'analyze'):
        value = meta.get(key)
        if not isinstance(value, str):
            continue
        for rel in _extract_candidates_from_command(value, impl_path, extensions):
            if rel not in seen:
                seen.add(rel)
                candidates.append(rel)

    # Second pass: fallback scan in source locations.
    search_patterns = ['src/**/*', 'bin/**/*', '*']
    for pattern in search_patterns:
        for ext in extensions:
            glob_pattern = os.path.join(impl_path, pattern + ext)
            for path in glob.glob(glob_pattern, recursive=True):
                if not os.path.isfile(path):
                    continue
                rel = _normalize_relpath(os.path.relpath(path, impl_path))
                if rel in seen:
                    continue
                if _is_generated_or_excluded_path(rel):
                    continue
                seen.add(rel)
                candidates.append(rel)

    if not candidates:
        return None

    # Pick highest score; for ties prefer shortest path.
    return max(candidates, key=lambda rel: (_entrypoint_score(rel), -len(rel)))

def _normalize_feature_name(feature: str) -> str:
    """Normalize feature names for matching and deduplication."""
    return feature.strip().lower().replace('-', '_').replace(' ', '_')

def format_feature_summary(meta: Dict[str, Any]) -> str:
    """Render feature completion as a compact implemented/total ratio."""
    raw_features = meta.get('features', [])
    if not isinstance(raw_features, list):
        raw_features = []

    normalized_catalog = [_normalize_feature_name(item) for item in FEATURE_CATALOG]
    catalog_set = set(normalized_catalog)

    # Deduplicate while preserving original order from metadata.
    normalized_seen = set()
    normalized_features: List[str] = []
    for item in raw_features:
        feature = _normalize_feature_name(str(item))
        if feature and feature not in normalized_seen:
            normalized_seen.add(feature)
            normalized_features.append(feature)

    matched_count = sum(1 for feature in normalized_features if feature in catalog_set)
    total_count = len(normalized_catalog)
    return f"{matched_count}/{total_count}"

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
    """Format durations with human-friendly units for README display."""
    if seconds is None:
        return "-"

    try:
        seconds_value = float(seconds)
    except (TypeError, ValueError):
        return "-"

    if seconds_value < 0:
        return "-"

    ms = seconds_value * 1000
    if ms < 1:
        return "<1ms"
    if ms < 10:
        return f"{ms:.1f}ms"
    if ms < 1000:
        return f"{ms:.0f}ms"
    if seconds_value < 60:
        seconds_text = f"{seconds_value:.1f}".rstrip("0").rstrip(".")
        return f"{seconds_text}s"

    rounded_seconds = int(round(seconds_value))
    minutes, remaining_seconds = divmod(rounded_seconds, 60)
    if minutes < 60:
        return f"{minutes}m {remaining_seconds:02d}s"

    hours, remaining_minutes = divmod(minutes, 60)
    return f"{hours}h {remaining_minutes:02d}m"

def format_grouped_int(value: Optional[float]) -> str:
    """Format integers with grouping separators."""
    if value is None:
        return "-"

    try:
        return f"{int(round(float(value))):,}"
    except (TypeError, ValueError):
        return "-"

def format_memory_mb(peak_memory_mb: float) -> str:
    """Format memory in MB with fallback when unavailable."""
    if peak_memory_mb is None or peak_memory_mb <= 0:
        return "- MB"
    return f"{format_grouped_int(peak_memory_mb)} MB"

def format_step_metric(seconds, peak_memory_mb: float) -> str:
    """Format one make step as '<duration>, <memory>'."""
    return f"{format_time(seconds)}, {format_memory_mb(peak_memory_mb)}"

def resolve_test_chess_engine_seconds(impl_data: Dict[str, Any]) -> Optional[float]:
    """Resolve shared suite duration from current or legacy timing keys."""
    timings = impl_data.get('timings', {})
    if not isinstance(timings, dict):
        return None

    test_chess_engine_step = timings.get('test_chess_engine_seconds')
    track_name = impl_data.get('track')
    if test_chess_engine_step is None and isinstance(track_name, str) and track_name.strip():
        legacy_track_key = f"test_{track_name.strip().replace('-', '_')}_seconds"
        test_chess_engine_step = timings.get(legacy_track_key)
    if test_chess_engine_step is None:
        legacy_fallback_keys = (
            "test_v2_full_seconds",
            "test_v2_system_seconds",
            "test_v2_functional_seconds",
            "test_v2_foundation_seconds",
            "test_v1_seconds",
        )
        for legacy_key in legacy_fallback_keys:
            if timings.get(legacy_key) is not None:
                test_chess_engine_step = timings.get(legacy_key)
                break

    return test_chess_engine_step

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
            tokens_count = resolve_tokens_count(impl_data, impl_path, meta, language)
            entrypoint_file = resolve_entrypoint_file(impl_path, language, meta)
            
            # Status
            if verification_data and language in verification_data:
                status = verification_data[language]
            else:
                status = classify_implementation_status(impl_data)
            
            emoji = status_emoji.get(status, '❓')
            lang_emoji = CUSTOM_EMOJIS.get(language, '📦')
            
            # Timings
            timings = impl_data.get('timings', {})
            build_step = timings.get('build_seconds')
            analyze_step = timings.get('analyze_seconds')
            test_step = timings.get('test_seconds')
            test_chess_engine_step = resolve_test_chess_engine_seconds(impl_data)
            
            # Memory
            memory_data = impl_data.get('memory', {})
            build_memory = memory_data.get('build', {}).get('peak_memory_mb', 0) if isinstance(memory_data.get('build', {}), dict) else 0
            analyze_memory = memory_data.get('analyze', {}).get('peak_memory_mb', 0) if isinstance(memory_data.get('analyze', {}), dict) else 0
            test_memory = memory_data.get('test', {}).get('peak_memory_mb', 0) if isinstance(memory_data.get('test', {}), dict) else 0
            test_chess_engine_memory = (
                memory_data.get('test_chess_engine', {}).get('peak_memory_mb', 0)
                if isinstance(memory_data.get('test_chess_engine', {}), dict)
                else 0
            )

            make_build_disp = format_step_metric(build_step, build_memory)
            make_analyze_disp = format_step_metric(analyze_step, analyze_memory)
            make_test_disp = format_step_metric(test_step, test_memory)
            make_test_chess_engine_disp = format_step_metric(test_chess_engine_step, test_chess_engine_memory)

            # Status + features
            feature_summary = f"{emoji} {format_feature_summary(meta)}"
            
            lang_name = f"{lang_emoji} {language.title()}"
            tokens_display = "-"
            if isinstance(tokens_count, int) and tokens_count >= 0:
                tokens_display = format_grouped_int(tokens_count)
            if entrypoint_file and isinstance(tokens_count, int) and tokens_count >= 0:
                entrypoint_repo_path = Path("implementations") / language / entrypoint_file
                tokens_display = f"[{format_grouped_int(tokens_count)}]({entrypoint_repo_path.as_posix()})"

            table_rows.append(
                f"| {lang_name} | {tokens_display} | "
                f"{make_build_disp} | {make_analyze_disp} | {make_test_disp} | {make_test_chess_engine_disp} | "
                f"{feature_summary} |"
            )
        
        # Create table content
        table_header = """
| Language | TOKENS | make build | make analyze | make test | make test-chess-engine | Features |
|----------|--------|------------|--------------|-----------|------------------------|----------|"""
        
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
