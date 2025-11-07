#!/usr/bin/env python3
"""
Generate static website for GitHub Pages with implementation comparison and source code explorer.
"""

import os
import json
import glob
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional
import shutil
import yaml
from datetime import datetime, timedelta


def load_language_statistics() -> Dict[str, Any]:
    """
    Load language statistics from language_statistics.yaml file.
    
    Returns a dictionary containing metadata and language statistics.
    """
    stats_file = "language_statistics.yaml"
    
    if not os.path.exists(stats_file):
        print(f"Warning: {stats_file} not found, using empty data")
        return {'metadata': {}, 'languages': {}}
    
    try:
        with open(stats_file, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
            return data if data else {'metadata': {}, 'languages': {}}
    except Exception as e:
        print(f"Error loading {stats_file}: {e}")
        return {'metadata': {}, 'languages': {}}


def check_statistics_freshness(stats_data: Dict[str, Any]) -> bool:
    """
    Check if language statistics are older than one month.
    
    Returns True if data should be updated, False otherwise.
    """
    metadata = stats_data.get('metadata', {})
    last_updated_str = metadata.get('last_updated')
    
    if not last_updated_str:
        print("Warning: No last_updated date found in statistics")
        return True
    
    try:
        last_updated = datetime.fromisoformat(last_updated_str)
        one_month_ago = datetime.now() - timedelta(days=30)
        
        if last_updated < one_month_ago:
            print(f"Statistics are outdated (last updated: {last_updated_str})")
            return True
        else:
            print(f"Statistics are fresh (last updated: {last_updated_str})")
            return False
    except Exception as e:
        print(f"Error parsing date: {e}")
        return True


def get_language_metadata() -> Dict[str, Dict[str, str]]:
    """
    Get metadata for each language including emoji, website, and popularity.
    
    Loads data from language_statistics.yaml file.
    """
    stats_data = load_language_statistics()
    languages_data = stats_data.get('languages', {})
    
    result = {}
    for lang_name, lang_info in languages_data.items():
        tiobe_rank = lang_info.get('tiobe_rank')
        tiobe_rank_str = 'N/A' if tiobe_rank is None else str(tiobe_rank)
        
        github_stars = lang_info.get('github_stars', 'N/A')
        # Keep the format consistent with existing code
        if github_stars != 'N/A':
            github_stars_str = f"{github_stars} repos"
        else:
            github_stars_str = 'N/A'
        
        result[lang_name] = {
            'emoji': lang_info.get('emoji', '📦'),
            'website': lang_info.get('website', '#'),
            'tiobe_rank': tiobe_rank_str,
            'github_stars': github_stars_str
        }
    
    return result


def get_statistics_sources() -> Dict[str, str]:
    """Get the source URLs for statistics data."""
    stats_data = load_language_statistics()
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
    perf_file = f"benchmark_reports/performance_data_{lang}.json"
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
    datatable_includes = ""
    if include_datatable:
        datatable_includes = """
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/jquery.dataTables.min.css">
    <script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>"""
    
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - The Great Analysis Challenge</title>
    <link rel="stylesheet" href="style.css">{datatable_includes}
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
</head>
<body>
    <header>
        <h1>🏆 The Great Analysis Challenge</h1>
        <p class="subtitle">Multi-Language Chess Engine Comparison</p>
        <nav>
            <a href="index.html">Home</a>
            <a href="https://github.com/evaisse/the-great-analysis-challenge">GitHub</a>
        </nav>
    </header>
    <main>
"""


def generate_html_footer() -> str:
    """Generate HTML footer."""
    sources = get_statistics_sources()
    last_updated = sources.get('last_updated', 'Unknown')
    tiobe_url = sources.get('tiobe_source', 'https://www.tiobe.com/tiobe-index/')
    github_url = sources.get('github_source', 'https://github.com/EvanLi/Github-Ranking')
    
    return f"""
    </main>
    <footer>
        <p>Generated from benchmark data. All implementations tested via Docker for consistency.</p>
        <p>Language popularity statistics from <a href="{tiobe_url}" target="_blank" rel="noopener">TIOBE Index</a> 
        and <a href="{github_url}" target="_blank" rel="noopener">GitHub Ranking</a> (last updated: {last_updated})</p>
        <p><a href="https://github.com/evaisse/the-great-analysis-challenge">View on GitHub</a></p>
    </footer>
</body>
</html>
"""


def format_time(seconds: float) -> str:
    """Format time in ms."""
    if seconds == 0:
        return "0ms"
    return f"{int(seconds * 1000)}ms"


def generate_comparison_table(all_data: List[Dict[str, Any]]) -> str:
    """Generate the comparison table HTML."""
    lang_metadata = get_language_metadata()
    
    html = '<h2>📊 Implementation Comparison</h2>\n'
    html += '<div class="table-container">\n'
    html += '<table id="comparison-table" class="comparison-table">\n'
    html += '<thead>\n<tr>\n'
    html += '<th>Language</th>\n'
    html += '<th>Version</th>\n'
    html += '<th>LOC</th>\n'
    html += '<th>Files</th>\n'
    html += '<th>Build Time (ms)</th>\n'
    html += '<th>Test Time (ms)</th>\n'
    html += '<th>Analyze Time (ms)</th>\n'
    html += '<th>TIOBE Rank</th>\n'
    html += '<th>GitHub Repos</th>\n'
    html += '<th>Features</th>\n'
    html += '<th>Source</th>\n'
    html += '</tr>\n</thead>\n<tbody>\n'
    
    for data in all_data:
        lang = data['language']
        metadata = data.get('metadata', {})
        perf = data.get('performance', {})
        loc = data.get('loc', {})
        timings = perf.get('timings', {})
        lang_meta = lang_metadata.get(lang, {'emoji': '📦', 'website': '#', 'tiobe_rank': 'N/A', 'github_stars': 'N/A'})
        
        # Get values
        version = metadata.get('version', 'N/A')
        loc_count = loc.get('loc', 0)
        file_count = loc.get('files', 0)
        build_time = int(timings.get('build_seconds', 0) * 1000)
        test_time = int(timings.get('test_seconds', 0) * 1000)
        analyze_time = int(timings.get('analyze_seconds', 0) * 1000)
        features = metadata.get('features', [])
        feature_icons = ''.join(['✅' if f in features else '❌' for f in ['perft', 'fen', 'ai']])
        
        # Parse TIOBE rank for sorting (N/A = 999 for sorting to bottom)
        tiobe_rank_str = lang_meta["tiobe_rank"]
        tiobe_rank_num = 999 if tiobe_rank_str == 'N/A' else int(tiobe_rank_str)
        
        # Parse GitHub repos for sorting
        github_str = lang_meta["github_stars"]
        # Extract numeric value: "10M+ repos" -> 10000000, "60K+ repos" -> 60000
        github_num = 0
        if github_str != 'N/A':
            try:
                if 'M+' in github_str:
                    github_num = int(float(github_str.split('M+')[0]) * 1000000)
                elif 'K+' in github_str:
                    github_num = int(float(github_str.split('K+')[0]) * 1000)
            except:
                github_num = 0
        
        html += '<tr>\n'
        html += f'<td><a href="{lang_meta["website"]}" target="_blank" rel="noopener">{lang_meta["emoji"]} <strong>{lang.capitalize()}</strong></a></td>\n'
        html += f'<td>{version}</td>\n'
        html += f'<td data-order="{loc_count}">{loc_count}</td>\n'
        html += f'<td data-order="{file_count}">{file_count}</td>\n'
        html += f'<td data-order="{build_time}">{build_time}</td>\n'
        html += f'<td data-order="{test_time}">{test_time}</td>\n'
        html += f'<td data-order="{analyze_time}">{analyze_time}</td>\n'
        html += f'<td data-order="{tiobe_rank_num}">{tiobe_rank_str}</td>\n'
        html += f'<td data-order="{github_num}">{github_str}</td>\n'
        html += f'<td>{feature_icons}</td>\n'
        html += f'<td><a href="source_{lang}.html">View Source</a></td>\n'
        html += '</tr>\n'
    
    html += '</tbody>\n</table>\n</div>\n'
    
    # Add DataTables initialization script
    html += """
<script>
$(document).ready(function() {
    $('#comparison-table').DataTable({
        "paging": false,
        "info": false,
        "order": [[2, "asc"]]  // Default sort by LOC
    });
});
</script>
"""
    
    return html


def generate_source_explorer(lang: str, impl_path: str) -> str:
    """Generate source code explorer page for an implementation."""
    lang_metadata = get_language_metadata()
    lang_meta = lang_metadata.get(lang, {'emoji': '📦', 'website': '#'})
    
    html = generate_html_header(f"{lang.capitalize()} Source Code", include_datatable=False)
    
    html += f'<h2>{lang_meta["emoji"]} <a href="{lang_meta["website"]}" target="_blank" rel="noopener">{lang.capitalize()}</a> Implementation</h2>\n'
    html += '<div class="breadcrumb"><a href="index.html">← Back to Comparison</a></div>\n'
    
    # Map language names to highlight.js language identifiers
    lang_map = {
        'crystal': 'crystal',
        'dart': 'dart',
        'elm': 'elm',
        'gleam': 'rust',  # Use rust as fallback for similar syntax
        'go': 'go',
        'haskell': 'haskell',
        'julia': 'julia',
        'kotlin': 'kotlin',
        'lua': 'lua',
        'mojo': 'python',  # Use python as fallback
        'nim': 'nim',
        'php': 'php',
        'python': 'python',
        'rescript': 'reasonml',
        'ruby': 'ruby',
        'rust': 'rust',
        'swift': 'swift',
        'typescript': 'typescript',
        'zig': 'zig'
    }
    
    highlight_lang = lang_map.get(lang, 'plaintext')
    
    # List all source files
    source_files = []
    for root, dirs, files in os.walk(impl_path):
        # Skip hidden and common directories
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['node_modules', 'target', 'build', 'dist', '__pycache__']]
        
        for file in files:
            if not file.startswith('.'):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, impl_path)
                source_files.append((rel_path, full_path))
    
    source_files.sort()
    
    html += '<div class="file-tree">\n'
    for rel_path, full_path in source_files:
        file_id = rel_path.replace('/', '_').replace('.', '_')
        
        # Determine language for syntax highlighting based on file extension
        ext = os.path.splitext(rel_path)[1]
        file_lang = highlight_lang
        ext_map = {
            '.rs': 'rust', '.py': 'python', '.go': 'go', '.ts': 'typescript',
            '.rb': 'ruby', '.cr': 'crystal', '.jl': 'julia', '.kt': 'kotlin',
            '.hs': 'haskell', '.gleam': 'rust', '.dart': 'dart', '.elm': 'elm',
            '.res': 'reasonml', '.mojo': 'python', '.swift': 'swift', '.zig': 'zig',
            '.nim': 'nim', '.toml': 'toml', '.json': 'json', '.yml': 'yaml',
            '.yaml': 'yaml', '.md': 'markdown', '.sh': 'bash', '.Dockerfile': 'dockerfile'
        }
        if ext in ext_map:
            file_lang = ext_map[ext]
        elif 'Dockerfile' in rel_path:
            file_lang = 'dockerfile'
        elif 'Makefile' in rel_path:
            file_lang = 'makefile'
        
        html += f'<div class="file-item">\n'
        html += f'<button class="file-toggle" onclick="toggleFile(\'{file_id}\')">📄 {rel_path}</button>\n'
        html += f'<pre id="{file_id}" class="file-content" style="display:none;"><code class="language-{file_lang}">'
        
        try:
            with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                # Escape HTML
                content = content.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                html += content
        except Exception as e:
            html += f"Error reading file: {e}"
        
        html += '</code></pre>\n</div>\n'
    
    html += '</div>\n'
    
    # Add JavaScript for toggling and syntax highlighting
    html += """
<script>
function toggleFile(id) {
    var content = document.getElementById(id);
    if (content.style.display === 'none') {
        content.style.display = 'block';
        // Highlight the code when first shown
        var codeBlock = content.querySelector('code');
        if (codeBlock && !codeBlock.classList.contains('hljs')) {
            hljs.highlightElement(codeBlock);
        }
    } else {
        content.style.display = 'none';
    }
}
</script>
"""
    
    html += generate_html_footer()
    return html


def generate_css() -> str:
    """Generate CSS stylesheet."""
    return """
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    line-height: 1.6;
    color: #333;
    background: #f5f5f5;
}

header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 2rem 1rem;
    text-align: center;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

header h1 {
    font-size: 2.5rem;
    margin-bottom: 0.5rem;
}

.subtitle {
    font-size: 1.2rem;
    opacity: 0.9;
    margin-bottom: 1rem;
}

nav {
    margin-top: 1rem;
}

nav a {
    color: white;
    text-decoration: none;
    margin: 0 1rem;
    padding: 0.5rem 1rem;
    border: 1px solid rgba(255,255,255,0.3);
    border-radius: 4px;
    transition: all 0.3s;
}

nav a:hover {
    background: rgba(255,255,255,0.1);
    border-color: white;
}

main {
    max-width: 1400px;
    margin: 2rem auto;
    padding: 0 1rem;
}

h2 {
    color: #667eea;
    margin: 2rem 0 1rem;
    font-size: 2rem;
}

h2 a {
    color: #667eea;
    text-decoration: none;
}

h2 a:hover {
    text-decoration: underline;
}

.intro {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    margin-bottom: 2rem;
}

.table-container {
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    overflow-x: auto;
    margin: 2rem 0;
    padding: 1rem;
}

.comparison-table {
    width: 100%;
    border-collapse: collapse;
}

.comparison-table th,
.comparison-table td {
    padding: 1rem;
    text-align: left;
    border-bottom: 1px solid #e0e0e0;
}

.comparison-table th {
    background: #f8f9fa;
    font-weight: 600;
    color: #667eea;
    position: sticky;
    top: 0;
    cursor: pointer;
}

.comparison-table th:hover {
    background: #e9ecef;
}

.comparison-table tr:hover {
    background: #f8f9fa;
}

.comparison-table a {
    color: #667eea;
    text-decoration: none;
    font-weight: 500;
}

.comparison-table a:hover {
    text-decoration: underline;
}

/* DataTables styling overrides */
.dataTables_wrapper .dataTables_filter {
    margin-bottom: 1rem;
}

.dataTables_wrapper .dataTables_filter input {
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 0.5rem;
    margin-left: 0.5rem;
}

.dataTables_wrapper .dataTables_length select {
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 0.5rem;
    margin: 0 0.5rem;
}

table.dataTable thead .sorting:before,
table.dataTable thead .sorting_asc:before,
table.dataTable thead .sorting_desc:before,
table.dataTable thead .sorting_asc_disabled:before,
table.dataTable thead .sorting_desc_disabled:before {
    right: 0.5em;
    content: "↕";
}

table.dataTable thead .sorting:after,
table.dataTable thead .sorting_asc:after,
table.dataTable thead .sorting_desc:after,
table.dataTable thead .sorting_asc_disabled:after,
table.dataTable thead .sorting_desc_disabled:after {
    right: 0.5em;
    content: "";
}

.breadcrumb {
    margin: 1rem 0;
}

.breadcrumb a {
    color: #667eea;
    text-decoration: none;
    font-weight: 500;
}

.breadcrumb a:hover {
    text-decoration: underline;
}

.file-tree {
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    padding: 1rem;
}

.file-item {
    margin: 0.5rem 0;
    border: 1px solid #e0e0e0;
    border-radius: 4px;
    overflow: hidden;
}

.file-toggle {
    width: 100%;
    padding: 0.75rem 1rem;
    background: #f8f9fa;
    border: none;
    text-align: left;
    cursor: pointer;
    font-size: 1rem;
    font-family: inherit;
    transition: background 0.2s;
}

.file-toggle:hover {
    background: #e9ecef;
}

.file-content {
    padding: 0;
    background: #282c34;
    color: #abb2bf;
    overflow-x: auto;
    font-size: 0.9rem;
    line-height: 1.5;
    margin: 0;
}

.file-content code {
    font-family: 'Courier New', Courier, monospace;
    display: block;
    padding: 1rem;
}

/* Highlight.js styling overrides */
.hljs {
    background: #282c34;
    color: #abb2bf;
}

footer {
    background: #333;
    color: white;
    text-align: center;
    padding: 2rem 1rem;
    margin-top: 4rem;
}

footer a {
    color: #667eea;
    text-decoration: none;
}

footer a:hover {
    text-decoration: underline;
}

@media (max-width: 768px) {
    header h1 {
        font-size: 1.8rem;
    }
    
    .comparison-table {
        font-size: 0.9rem;
    }
    
    .comparison-table th,
    .comparison-table td {
        padding: 0.5rem;
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
    index_html = generate_html_header("Implementation Comparison", include_datatable=True)
    index_html += '<section class="intro">\n'
    index_html += '<p>Welcome to The Great Analysis Challenge! This project implements identical chess engines across different programming languages to compare their approaches, performance, and unique paradigms.</p>\n'
    index_html += '<p>Below you\'ll find a comprehensive comparison of all implementations, including lines of code, build times, and feature support. Click on column headers to sort the table.</p>\n'
    index_html += '</section>\n'
    index_html += generate_comparison_table(all_data)
    index_html += generate_html_footer()
    
    with open(os.path.join(docs_dir, 'index.html'), 'w') as f:
        f.write(index_html)
    
    # Generate source explorer pages
    print("📁 Generating source explorer pages...")
    for data in all_data:
        lang = data['language']
        impl_path = data['path']
        print(f"  - {lang}")
        
        source_html = generate_source_explorer(lang, impl_path)
        with open(os.path.join(docs_dir, f'source_{lang}.html'), 'w') as f:
            f.write(source_html)
    
    # Generate CSS
    print("🎨 Generating CSS...")
    with open(os.path.join(docs_dir, 'style.css'), 'w') as f:
        f.write(generate_css())
    
    # Create .nojekyll file to disable Jekyll processing
    with open(os.path.join(docs_dir, '.nojekyll'), 'w') as f:
        f.write('')
    
    print(f"✅ Website built successfully in {docs_dir}/")
    print(f"   - Main page: {docs_dir}/index.html")
    print(f"   - Source explorers: {len(all_data)} pages")


if __name__ == '__main__':
    main()
