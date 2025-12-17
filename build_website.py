#!/usr/bin/env python3
"""Generate a lo-fi static website summarising implementation metrics."""

import glob
import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any

try:
    import yaml  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    yaml = None

FAVICON_SVG = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="12" fill="#111827"/>
  <path fill="#fef3c7" d="M12 16h40v4H12zM12 30h40v4H12zM12 44h40v4H12z"/>
  <circle cx="20" cy="18" r="3" fill="#facc15"/>
  <circle cx="32" cy="32" r="3" fill="#facc15"/>
  <circle cx="44" cy="46" r="3" fill="#facc15"/>
</svg>
"""

CUSTOM_EMOJIS: Dict[str, str] = {
    'python': '🐍',
    'crystal': '💠',
    'dart': '🎯',
    'elm': '🌳',
    'gleam': '✨',
    'go': '🐹',
    'haskell': '📐',
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

LATEST_MAJOR_RELEASES: Dict[str, str] = {
    'python': '2023-10-02',
    'crystal': '2024-07-18',
    'dart': '2024-06-20',
    'elm': '2019-10-21',
    'gleam': '2024-06-06',
    'go': '2024-02-06',
    'haskell': '2024-03-01',
    'julia': '2024-06-13',
    'kotlin': '2024-05-21',
    'lua': '2023-09-15',
    'mojo': '2024-08-30',
    'nim': '2023-11-16',
    'php': '2023-11-23',
    'rescript': '2024-02-19',
    'ruby': '2023-12-25',
    'rust': '2024-07-25',
    'swift': '2024-03-07',
    'typescript': '2024-05-21',
    'zig': '2024-06-21'
}

FALLBACK_METADATA: Dict[str, Dict[str, str]] = {
    lang: {
        'emoji': emoji,
        'website': url,
        'tiobe_rank': rank,
        'github_stars': stars,
        'latest_major_release': LATEST_MAJOR_RELEASES.get(lang, 'n/a')
    }
    for lang, emoji, url, rank, stars in [
        ('python', '🐍', 'https://www.python.org/', '1', '10M+ repos'),
        ('crystal', '💠', 'https://crystal-lang.org/', 'N/A', '60K+ repos'),
        ('dart', '🎯', 'https://dart.dev/', '25', '1M+ repos'),
        ('elm', '🌳', 'https://elm-lang.org/', 'N/A', '100K+ repos'),
        ('gleam', '✨', 'https://gleam.run/', 'N/A', '15K+ repos'),
        ('go', '🐹', 'https://go.dev/', '8', '3.5M+ repos'),
        ('haskell', '📐', 'https://www.haskell.org/', '38', '500K+ repos'),
        ('julia', '🔮', 'https://julialang.org/', '30', '200K+ repos'),
        ('kotlin', '🧡', 'https://kotlinlang.org/', '24', '1.5M+ repos'),
        ('lua', '🪐', 'https://www.lua.org/', '26', '1M+ repos'),
        ('mojo', '🔥', 'https://www.modular.com/mojo', 'N/A', '20K+ repos'),
        ('nim', '🦊', 'https://nim-lang.org/', 'N/A', '100K+ repos'),
        ('php', '🐘', 'https://www.php.net/', '7', '8M+ repos'),
        ('rescript', '🧠', 'https://rescript-lang.org/', 'N/A', '50K+ repos'),
        ('ruby', '❤️', 'https://www.ruby-lang.org/', '17', '2M+ repos'),
        ('rust', '🦀', 'https://www.rust-lang.org/', '14', '4.5M+ repos'),
        ('swift', '🐦', 'https://www.swift.org/', '15', '2.5M+ repos'),
        ('typescript', '📘', 'https://www.typescriptlang.org/', '20', '5M+ repos'),
        ('zig', '⚡', 'https://ziglang.org/', 'N/A', '150K+ repos'),
    ]
}


def load_language_statistics() -> Dict[str, Any]:
    """Load language statistics from language_statistics.yaml."""
    stats_file = "language_statistics.yaml"

    if yaml is None:
        print("Warning: PyYAML not available; skipping language statistics")
        return {'metadata': {}, 'languages': {}}

    if not os.path.exists(stats_file):
        print(f"Warning: {stats_file} not found, using empty data")
        return {'metadata': {}, 'languages': {}}

    try:
        with open(stats_file, 'r', encoding='utf-8') as handle:
            data = yaml.safe_load(handle)
            return data if data else {'metadata': {}, 'languages': {}}
    except Exception as exc:
        print(f"Error loading {stats_file}: {exc}")
        return {'metadata': {}, 'languages': {}}


def check_statistics_freshness(stats_data: Dict[str, Any]) -> bool:
    """Return True when statistics are older than ~30 days."""
    metadata = stats_data.get('metadata', {})
    last_updated_str = metadata.get('last_updated')

    if not last_updated_str:
        print("Warning: No last_updated date found in statistics")
        return True

    try:
        last_updated = datetime.fromisoformat(last_updated_str)
        if last_updated < datetime.now() - timedelta(days=30):
            print(f"Statistics are outdated (last updated: {last_updated_str})")
            return True
        print(f"Statistics are fresh (last updated: {last_updated_str})")
        return False
    except Exception as exc:
        print(f"Error parsing statistics date: {exc}")
        return True


def get_language_metadata(stats_data: Dict[str, Any]) -> Dict[str, Dict[str, str]]:
    """Transform statistics into the metadata used by the website."""
    languages_data = stats_data.get('languages', {})
    result: Dict[str, Dict[str, str]] = {}

    for lang_name, lang_info in languages_data.items():
        tiobe_rank = lang_info.get('tiobe_rank')
        github_stars = lang_info.get('github_stars', 'N/A')
        emoji = CUSTOM_EMOJIS.get(lang_name, lang_info.get('emoji', '📦'))
        latest_release = LATEST_MAJOR_RELEASES.get(lang_name, 'n/a')

        result[lang_name] = {
            'emoji': emoji,
            'website': lang_info.get('website', FALLBACK_METADATA.get(lang_name, {}).get('website', '#')),
            'tiobe_rank': 'N/A' if tiobe_rank is None else str(tiobe_rank),
            'github_stars': f"{github_stars} repos" if github_stars != 'N/A' else 'N/A',
            'latest_major_release': latest_release
        }

    for lang_name, fallback in FALLBACK_METADATA.items():
        result.setdefault(lang_name, fallback)

    return result


def get_statistics_sources(stats_data: Dict[str, Any]) -> Dict[str, str]:
    metadata = stats_data.get('metadata', {})
    return {
        'tiobe_source': metadata.get('tiobe_source', 'https://www.tiobe.com/tiobe-index/'),
        'github_source': metadata.get('github_source', 'https://github.com/EvanLi/Github-Ranking'),
        'last_updated': metadata.get('last_updated', 'Unknown')
    }


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


def load_performance_data(lang: str) -> Dict[str, Any]:
    """Load performance data for a language."""
    perf_file = f"reports/{lang}.json"
    if os.path.exists(perf_file):
        try:
            with open(perf_file, 'r', encoding='utf-8') as handle:
                data = json.load(handle)
                if isinstance(data, list) and data:
                    return data[0]
        except Exception as exc:
            print(f"Error loading {perf_file}: {exc}")
    return {}


def load_metadata(impl_path: str) -> Dict[str, Any]:
    """Load chess.meta for an implementation."""
    meta_file = os.path.join(impl_path, 'chess.meta')
    if os.path.exists(meta_file):
        try:
            with open(meta_file, 'r', encoding='utf-8') as handle:
                return json.load(handle)
        except Exception as exc:
            print(f"Error loading {meta_file}: {exc}")
    return {}


def discover_implementations() -> List[str]:
    impl_dir = "implementations"
    if not os.path.exists(impl_dir):
        return []
    return sorted([name for name in os.listdir(impl_dir) if os.path.isdir(os.path.join(impl_dir, name))])


def is_valid_performance_data(performance: Dict[str, Any]) -> bool:
    """Check if performance data meets benchmark output constraints.
    
    Valid performance data must have:
    - status = "completed"
    - build_seconds is not None
    - test_seconds is not None
    
    This ensures only implementations with complete, successful benchmarks are displayed.
    """
    if not performance:
        return False
    
    # Check status
    status = performance.get('status')
    if status != 'completed':
        return False
    
    # Check required timing data
    timings = performance.get('timings', {})
    build_seconds = timings.get('build_seconds')
    test_seconds = timings.get('test_seconds')
    
    # Both build and test times must be present (not None)
    if build_seconds is None or test_seconds is None:
        return False
    
    return True


def gather_all_data(language_metadata: Dict[str, Dict[str, str]]) -> List[Dict[str, Any]]:
    implementations = discover_implementations()
    all_data: List[Dict[str, Any]] = []

    for lang in implementations:
        impl_path = f"implementations/{lang}"
        meta = load_metadata(impl_path)
        language_info = language_metadata.get(lang, {})
        performance = load_performance_data(lang)

        # Only include implementations with valid performance data
        if not is_valid_performance_data(performance):
            print(f"⚠️  Skipping {lang}: incomplete or failed benchmark (status={performance.get('status', 'missing')})")
            continue

        data = {
            'language': lang,
            'path': impl_path,
            'metadata': meta,
            'language_metadata': language_info,
            'performance': performance,
            'loc': count_lines_of_code(impl_path)
        }
        all_data.append(data)

    return all_data


def generate_html_header(title: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} · The Great Analysis Challenge</title>
    <link rel="icon" href="favicon.svg" type="image/svg+xml">
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header>
        <h1>The Great Analysis Challenge</h1>
        <p class="subtitle">polyglot chess engine benchmarking logbook</p>
        <p class="links"><a href="https://github.com/evaisse/the-great-analysis-challenge">github.com/evaisse/the-great-analysis-challenge</a></p>
    </header>
    <main>
"""


def generate_html_footer() -> str:
    return """
    </main>
    <footer>
        <p>benchmarks, docs, and tooling live together in the repo.</p>
        <p><a href="https://github.com/evaisse/the-great-analysis-challenge">github.com/evaisse/the-great-analysis-challenge</a></p>
    </footer>
    <script>
    (function() {
        const table = document.querySelector('.comparison-table');
        if (!table) return;
        const headers = Array.from(table.querySelectorAll('th'));
        const tbody = table.tBodies[0];
        headers.forEach((header, index) => {
            header.addEventListener('click', () => {
                const ascending = !header.classList.contains('sort-asc');
                headers.forEach(h => h.classList.remove('sort-asc', 'sort-desc'));
                header.classList.add(ascending ? 'sort-asc' : 'sort-desc');
                const rows = Array.from(tbody.querySelectorAll('tr'));
                rows.sort((a, b) => {
                    const cellA = a.cells[index];
                    const cellB = b.cells[index];
                    const rawA = cellA ? (cellA.dataset.sort ?? cellA.textContent.trim()) : '';
                    const rawB = cellB ? (cellB.dataset.sort ?? cellB.textContent.trim()) : '';
                    const valueA = rawA.toLowerCase() === 'infinity' ? Infinity : rawA;
                    const valueB = rawB.toLowerCase() === 'infinity' ? Infinity : rawB;
                    const numA = Number(valueA);
                    const numB = Number(valueB);
                    const bothNumeric = !Number.isNaN(numA) && !Number.isNaN(numB);
                    let comparison;
                    if (bothNumeric) {
                        comparison = numA - numB;
                    } else {
                        comparison = String(valueA).localeCompare(String(valueB), undefined, { numeric: true });
                    }
                    return ascending ? comparison : -comparison;
                });
                rows.forEach(row => tbody.appendChild(row));
            });
        });
    })();
    </script>
</body>
</html>
"""


def generate_comparison_table(all_data: List[Dict[str, Any]], stats_context: Dict[str, str]) -> str:
    last_updated = stats_context.get('last_updated', 'Unknown')
    tiobe_source = stats_context.get('tiobe_source', 'https://www.tiobe.com/tiobe-index/')
    github_source = stats_context.get('github_source', 'https://github.com/EvanLi/Github-Ranking')

    html = '<h2>implementation ledger</h2>\n'
    html += (
        f'<p class="note">stats last refreshed: {last_updated} · '
        f'sources: <a href="{tiobe_source}">TIOBE</a>, '
        f'<a href="{github_source}">GitHub trends</a>. '
        'times are rough milliseconds from Docker runs; features follow `chess.meta` declarations.</p>\n'
    )
    html += '<table class="comparison-table">\n'
    html += '<thead>\n<tr>\n'
    html += '<th>language</th>\n'
    html += '<th>latest major</th>\n'
    html += '<th>loc</th>\n'
    html += '<th>files</th>\n'
    html += '<th>build (ms)</th>\n'
    html += '<th>test (ms)</th>\n'
    html += '<th>analyze (ms)</th>\n'
    html += '<th>features</th>\n'
    html += '<th>source</th>\n'
    html += '</tr>\n</thead>\n<tbody>\n'

    repo_base = "https://github.com/evaisse/the-great-analysis-challenge/tree/master/implementations"

    for data in all_data:
        lang = data['language']
        meta = data.get('metadata', {})
        language_info = data.get('language_metadata', {})
        performance = data.get('performance', {})
        loc = data.get('loc', {})
        timings = performance.get('timings', {})

        def fmt_time(value: Any) -> (str, str):
            if value is None:
                return '—', 'Infinity'
            millis = int(round(value * 1000))
            return str(millis), str(millis)

        build_disp, build_sort = fmt_time(timings.get('build_seconds'))
        test_disp, test_sort = fmt_time(timings.get('test_seconds'))
        analyze_disp, analyze_sort = fmt_time(timings.get('analyze_seconds'))

        features = meta.get('features', []) if isinstance(meta.get('features'), list) else []
        feature_summary = ', '.join(features) if features else 'n/a'
        feature_sort = ' '.join(sorted(features)) if features else ''

        repo_url = f"{repo_base}/{lang}"
        latest_release = language_info.get('latest_major_release', 'n/a')
        latest_sort = latest_release if latest_release != 'n/a' else '0000-00-00'

        emoji = language_info.get('emoji', '□')
        website = language_info.get('website', '#')

        html += '<tr>\n'
        html += (
            f'<td data-sort="{lang.lower()}"><span class="emoji">{emoji}</span> '
            f'<a href="{website}" target="_blank" rel="noopener">{lang.capitalize()}</a></td>\n'
        )
        html += f'<td data-sort="{latest_sort}">{latest_release}</td>\n'
        html += f'<td class="numeric" data-sort="{loc.get("loc", 0)}">{loc.get("loc", 0)}</td>\n'
        html += f'<td class="numeric" data-sort="{loc.get("files", 0)}">{loc.get("files", 0)}</td>\n'
        html += f'<td class="numeric" data-sort="{build_sort}">{build_disp}</td>\n'
        html += f'<td class="numeric" data-sort="{test_sort}">{test_disp}</td>\n'
        html += f'<td class="numeric" data-sort="{analyze_sort}">{analyze_disp}</td>\n'
        html += f'<td data-sort="{feature_sort}">{feature_summary}</td>\n'
        html += f'<td data-sort="{repo_url}"><a href="{repo_url}" target="_blank" rel="noopener">view repo</a></td>\n'
        html += '</tr>\n'

    html += '</tbody>\n</table>\n'
    return html


def generate_css() -> str:
    return """
:root {
    color-scheme: light;
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: 'IBM Plex Mono', 'Fira Code', 'Courier New', monospace;
    background: #fdf6e3;
    color: #1f2933;
    line-height: 1.7;
}

header {
    background: #111827;
    color: #fef3c7;
    text-align: center;
    padding: 2.8rem 1rem 2.2rem;
    border-bottom: 4px solid #facc15;
}

header h1 {
    margin: 0 0 0.5rem;
    font-size: 2.25rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
}

.subtitle {
    margin: 0 0 0.75rem;
    font-size: 1rem;
    color: #fcd34d;
    letter-spacing: 0.12em;
}

.links {
    font-size: 0.95rem;
}

.links a {
    color: #facc15;
    text-decoration: none;
}

.links a:hover {
    text-decoration: underline;
}

main {
    max-width: 960px;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
}

h2 {
    font-size: 1.4rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    margin: 2rem 0 0.5rem;
}

p {
    margin: 0 0 1.1rem;
}

.note {
    font-size: 0.9rem;
    color: #4b5563;
    margin-bottom: 1.4rem;
}

.comparison-table {
    width: 100%;
    border-collapse: collapse;
    background: #fffdf7;
    border: 2px solid #d1c89f;
    box-shadow: 0 4px 0 #d1c89f;
}

.comparison-table th,
.comparison-table td {
    padding: 0.65rem 0.85rem;
    border-bottom: 1px solid #d1c89f;
}

.comparison-table th {
    background: #f5edd5;
    font-weight: 600;
    text-transform: lowercase;
    letter-spacing: 0.05em;
    cursor: pointer;
}

.comparison-table tbody tr:nth-child(even) {
    background: #fdf1d6;
}

.comparison-table tbody tr:hover {
    background: #fbeac0;
}

.comparison-table a {
    color: #2563eb;
    text-decoration: none;
}

.comparison-table a:hover {
    text-decoration: underline;
}

.numeric {
    text-align: right;
}

.emoji {
    margin-right: 0.35rem;
}

.comparison-table th.sort-asc::after {
    content: " ▲";
    font-size: 0.75rem;
}

.comparison-table th.sort-desc::after {
    content: " ▼";
    font-size: 0.75rem;
}

footer {
    margin-top: 3rem;
    padding: 1.5rem 1rem;
    border-top: 2px solid #d1c89f;
    font-size: 0.9rem;
    color: #4b5563;
}

footer a {
    color: #2563eb;
    text-decoration: none;
}

footer a:hover {
    text-decoration: underline;
}

@media (max-width: 720px) {
    header h1 {
        font-size: 1.65rem;
    }

    .comparison-table {
        font-size: 0.85rem;
    }

    .comparison-table th,
    .comparison-table td {
        padding: 0.45rem 0.6rem;
    }
}
"""


def main() -> None:
    print("🚀 Building static website...")
    docs_dir = "docs"
    os.makedirs(docs_dir, exist_ok=True)

    stats_data = load_language_statistics()
    check_statistics_freshness(stats_data)
    language_metadata = get_language_metadata(stats_data)
    stats_context = get_statistics_sources(stats_data)

    all_data = gather_all_data(language_metadata)

    print("📄 Generating comparison page...")
    index_html = generate_html_header("Implementation Comparison")
    index_html += '<p>This sheet captures every chess engine build in the experiment. Each row is an implementation living in its own Dockerized world. Keep it simple, verify the numbers, adjust when benchmarks drift.</p>\n'
    index_html += '<p>Times are gathered from the automated workflow; all commands execute inside Docker for parity. Explore the repository links to inspect the code directly.</p>\n'
    index_html += generate_comparison_table(all_data, stats_context)
    index_html += generate_html_footer()

    with open(os.path.join(docs_dir, 'index.html'), 'w', encoding='utf-8') as handle:
        handle.write(index_html)

    removed_sources = 0
    for legacy in glob.glob(os.path.join(docs_dir, 'source_*.html')):
        os.remove(legacy)
        removed_sources += 1
    if removed_sources:
        print(f"🧹 Removed {removed_sources} legacy source explorer page(s)")

    print("🎨 Generating CSS...")
    with open(os.path.join(docs_dir, 'style.css'), 'w', encoding='utf-8') as handle:
        handle.write(generate_css())

    with open(os.path.join(docs_dir, 'favicon.svg'), 'w', encoding='utf-8') as handle:
        handle.write(FAVICON_SVG.strip() + "\n")

    with open(os.path.join(docs_dir, '.nojekyll'), 'w', encoding='utf-8') as handle:
        handle.write('')

    print(f"✅ Website built successfully in {docs_dir}/")
    print(f"   - Main page: {docs_dir}/index.html")
    print(f"   - Implementations tracked: {len(all_data)}")


if __name__ == '__main__':
    main()
