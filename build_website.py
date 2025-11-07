#!/usr/bin/env python3
"""Generate a lo-fi static website summarising implementation metrics."""

import glob
import json
import os
from typing import Dict, List, Any

FAVICON_SVG = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="12" fill="#111827"/>
  <path fill="#fef3c7" d="M12 16h40v4H12zM12 30h40v4H12zM12 44h40v4H12z"/>
  <circle cx="20" cy="18" r="3" fill="#facc15"/>
  <circle cx="32" cy="32" r="3" fill="#facc15"/>
  <circle cx="44" cy="46" r="3" fill="#facc15"/>
</svg>
"""

def get_language_metadata() -> Dict[str, Dict[str, str]]:
    """Get metadata for each language including emoji, website, and popularity."""
    return {
        'python': {
            'emoji': '🐍',
            'website': 'https://www.python.org/',
            'tiobe_rank': '1',
            'github_stars': '10M+ repos',
            'latest_major_release': '2023-10-02'
        },
        'go': {
            'emoji': '🐹',
            'website': 'https://go.dev/',
            'tiobe_rank': '8',
            'github_stars': '3.5M+ repos',
            'latest_major_release': '2024-02-06'
        },
        'typescript': {
            'emoji': '📘',
            'website': 'https://www.typescriptlang.org/',
            'tiobe_rank': '20',
            'github_stars': '5M+ repos',
            'latest_major_release': '2024-05-21'
        },
        'ruby': {
            'emoji': '❤️',
            'website': 'https://www.ruby-lang.org/',
            'tiobe_rank': '17',
            'github_stars': '2M+ repos',
            'latest_major_release': '2023-12-25'
        },
        'crystal': {
            'emoji': '💠',
            'website': 'https://crystal-lang.org/',
            'tiobe_rank': 'N/A',
            'github_stars': '60K+ repos',
            'latest_major_release': '2024-07-18'
        },
        'julia': {
            'emoji': '🔮',
            'website': 'https://julialang.org/',
            'tiobe_rank': '30',
            'github_stars': '200K+ repos',
            'latest_major_release': '2024-06-13'
        },
        'kotlin': {
            'emoji': '🧡',
            'website': 'https://kotlinlang.org/',
            'tiobe_rank': '24',
            'github_stars': '1.5M+ repos',
            'latest_major_release': '2024-05-21'
        },
        'haskell': {
            'emoji': '📐',
            'website': 'https://www.haskell.org/',
            'tiobe_rank': '38',
            'github_stars': '500K+ repos',
            'latest_major_release': '2024-03-01'
        },
        'gleam': {
            'emoji': '✨',
            'website': 'https://gleam.run/',
            'tiobe_rank': 'N/A',
            'github_stars': '15K+ repos',
            'latest_major_release': '2024-06-06'
        },
        'rust': {
            'emoji': '🦀',
            'website': 'https://www.rust-lang.org/',
            'tiobe_rank': '14',
            'github_stars': '4.5M+ repos',
            'latest_major_release': '2024-07-25'
        },
        'dart': {
            'emoji': '🎯',
            'website': 'https://dart.dev/',
            'tiobe_rank': '25',
            'github_stars': '1M+ repos',
            'latest_major_release': '2024-06-20'
        },
        'elm': {
            'emoji': '🌳',
            'website': 'https://elm-lang.org/',
            'tiobe_rank': 'N/A',
            'github_stars': '100K+ repos',
            'latest_major_release': '2019-10-21'
        },
        'rescript': {
            'emoji': '🧠',
            'website': 'https://rescript-lang.org/',
            'tiobe_rank': 'N/A',
            'github_stars': '50K+ repos',
            'latest_major_release': '2024-02-19'
        },
        'mojo': {
            'emoji': '🔥',
            'website': 'https://www.modular.com/mojo',
            'tiobe_rank': 'N/A',
            'github_stars': '20K+ repos',
            'latest_major_release': '2024-08-30'
        },
        'swift': {
            'emoji': '🐦',
            'website': 'https://www.swift.org/',
            'tiobe_rank': '15',
            'github_stars': '2.5M+ repos',
            'latest_major_release': '2024-03-07'
        },
        'zig': {
            'emoji': '⚡',
            'website': 'https://ziglang.org/',
            'tiobe_rank': 'N/A',
            'github_stars': '150K+ repos',
            'latest_major_release': '2024-06-21'
        },
        'nim': {
            'emoji': '🦊',
            'website': 'https://nim-lang.org/',
            'tiobe_rank': 'N/A',
            'github_stars': '100K+ repos',
            'latest_major_release': '2023-11-16'
        },
        'lua': {
            'emoji': '🪐',
            'website': 'https://www.lua.org/',
            'tiobe_rank': '26',
            'github_stars': '1M+ repos',
            'latest_major_release': '2023-09-15'
        },
        'php': {
            'emoji': '🐘',
            'website': 'https://www.php.net/',
            'tiobe_rank': '7',
            'github_stars': '8M+ repos',
            'latest_major_release': '2023-11-23'
        }
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
    
    # Find source files
    src_dir = os.path.join(impl_path, 'src')
    if not os.path.exists(src_dir):
        # Try root directory
        src_dir = impl_path
    
    for ext in exts:
        pattern = f"{src_dir}/**/*{ext}"
        files = glob.glob(pattern, recursive=True)
        for file in files:
            try:
                with open(file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = len(f.readlines())
                    total_loc += lines
                    file_count += 1
            except Exception:
                pass
    
    return {'loc': total_loc, 'files': file_count}


def load_performance_data(lang: str) -> Dict[str, Any]:
    """Load performance data for a language."""
    perf_file = f"reports/{lang}.json"
    if os.path.exists(perf_file):
        try:
            with open(perf_file, 'r') as f:
                data = json.load(f)
                if isinstance(data, list) and len(data) > 0:
                    return data[0]
        except Exception as e:
            print(f"Error loading {perf_file}: {e}")
    return {}


def load_metadata(impl_path: str) -> Dict[str, Any]:
    """Load chess.meta for an implementation."""
    meta_file = os.path.join(impl_path, 'chess.meta')
    if os.path.exists(meta_file):
        try:
            with open(meta_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading {meta_file}: {e}")
    return {}


def discover_implementations() -> List[str]:
    """Discover all implementations."""
    impl_dir = "implementations"
    implementations = []
    
    if not os.path.exists(impl_dir):
        return implementations
    
    for name in sorted(os.listdir(impl_dir)):
        impl_path = os.path.join(impl_dir, name)
        if os.path.isdir(impl_path):
            implementations.append(name)
    
    return implementations


def gather_all_data() -> List[Dict[str, Any]]:
    """Gather all data for all implementations."""
    implementations = discover_implementations()
    all_data = []
    
    for lang in implementations:
        impl_path = f"implementations/{lang}"
        
        print(f"Gathering data for {lang}...")
        
        data = {
            'language': lang,
            'path': impl_path,
            'metadata': load_metadata(impl_path),
            'performance': load_performance_data(lang),
            'loc': count_lines_of_code(impl_path)
        }
        
        all_data.append(data)
    
    return all_data


def generate_html_header(title: str, include_datatable: bool = False) -> str:
    """Generate HTML header."""
    _ = include_datatable  # Parameter preserved for compatibility
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
    """Generate HTML footer."""
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


def generate_comparison_table(all_data: List[Dict[str, Any]]) -> str:
    """Generate the comparison table HTML."""
    lang_metadata = get_language_metadata()
    repo_base = "https://github.com/evaisse/the-great-analysis-challenge/tree/master/implementations"

    html = '<h2>implementation ledger</h2>\n'
    html += '<p class="note">times are rough milliseconds from Docker runs; latest major is recorded as ISO dates; features reflect the `chess.meta` declarations.</p>\n'
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

    for data in all_data:
        lang = data['language']
        metadata = data.get('metadata', {})
        perf = data.get('performance', {})
        loc = data.get('loc', {})
        timings = perf.get('timings', {})
        lang_meta = lang_metadata.get(
            lang,
            {'emoji': '□', 'website': '#', 'latest_major_release': 'n/a'}
        )

        loc_count = loc.get('loc', 0)
        file_count = loc.get('files', 0)

        def fmt_time(value):
            if value is None:
                return '—', 'Infinity'
            millis = int(round(value * 1000))
            return str(millis), str(millis)

        build_time_disp, build_time_sort = fmt_time(timings.get('build_seconds'))
        test_time_disp, test_time_sort = fmt_time(timings.get('test_seconds'))
        analyze_time_disp, analyze_time_sort = fmt_time(timings.get('analyze_seconds'))

        features = metadata.get('features', [])
        feature_summary = ', '.join(features) if features else 'n/a'
        feature_sort = ' '.join(sorted(features)) if features else ''

        repo_url = f"{repo_base}/{lang}"
        latest_release = lang_meta.get('latest_major_release', 'n/a')
        latest_sort = latest_release if latest_release != 'n/a' else '0000-00-00'

        html += '<tr>\n'
        html += (
            f'<td data-sort="{lang.lower()}"><span class="emoji">{lang_meta["emoji"]}</span> '
            f'<a href="{lang_meta["website"]}" target="_blank" rel="noopener">{lang.capitalize()}</a></td>\n'
        )
        html += f'<td data-sort="{latest_sort}">{latest_release}</td>\n'
        html += f'<td class="numeric" data-sort="{loc_count}">{loc_count}</td>\n'
        html += f'<td class="numeric" data-sort="{file_count}">{file_count}</td>\n'
        html += f'<td class="numeric" data-sort="{build_time_sort}">{build_time_disp}</td>\n'
        html += f'<td class="numeric" data-sort="{test_time_sort}">{test_time_disp}</td>\n'
        html += f'<td class="numeric" data-sort="{analyze_time_sort}">{analyze_time_disp}</td>\n'
        html += f'<td data-sort="{feature_sort}">{feature_summary}</td>\n'
        html += f'<td data-sort="{repo_url}"><a href="{repo_url}" target="_blank" rel="noopener">view repo</a></td>\n'
        html += '</tr>\n'

    html += '</tbody>\n</table>\n'
    return html


def generate_css() -> str:
    """Generate CSS stylesheet."""
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


def main():
    """Main function to build the website."""
    print("🚀 Building static website...")
    
    # Create docs directory
    docs_dir = "docs"
    os.makedirs(docs_dir, exist_ok=True)
    
    # Gather all data
    all_data = gather_all_data()
    
    # Generate main comparison page
    print("📄 Generating comparison page...")
    index_html = generate_html_header("Implementation Comparison", include_datatable=False)
    index_html += '<p>This sheet captures every chess engine build in the experiment. Each row is an implementation living in its own Dockerized world. Keep it simple, verify the numbers, adjust when benchmarks drift.</p>\n'
    index_html += '<p>Times are gathered from the automated workflow; all commands execute inside Docker for parity. Explore the repository links to inspect the code directly.</p>\n'
    index_html += generate_comparison_table(all_data)
    index_html += generate_html_footer()
    
    with open(os.path.join(docs_dir, 'index.html'), 'w') as f:
        f.write(index_html)

    # Remove legacy source explorer pages if they remain
    removed_sources = 0
    for legacy in glob.glob(os.path.join(docs_dir, 'source_*.html')):
        os.remove(legacy)
        removed_sources += 1
    if removed_sources:
        print(f"🧹 Removed {removed_sources} legacy source explorer page(s)")
    
    # Generate CSS
    print("🎨 Generating CSS...")
    with open(os.path.join(docs_dir, 'style.css'), 'w') as f:
        f.write(generate_css())
    
    # Write favicon
    with open(os.path.join(docs_dir, 'favicon.svg'), 'w') as f:
        f.write(FAVICON_SVG.strip() + "\n")
    
    # Create .nojekyll file to disable Jekyll processing
    with open(os.path.join(docs_dir, '.nojekyll'), 'w') as f:
        f.write('')
    
    print(f"✅ Website built successfully in {docs_dir}/")
    print(f"   - Main page: {docs_dir}/index.html")
    print(f"   - Implementations tracked: {len(all_data)}")


if __name__ == '__main__':
    main()
