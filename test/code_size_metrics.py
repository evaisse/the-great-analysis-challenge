#!/usr/bin/env python3
"""Collect normalized implementation code size metrics."""

import argparse
import json
from pathlib import Path
from typing import Dict, Iterable, List

EXCLUDED_DIRS = {
    "node_modules",
    "vendor",
    "dist",
    "build",
    "target",
    ".dart_tool",
    "elm-stuff",
    ".git",
    ".next",
    "coverage",
    "__pycache__",
}

SOURCE_EXTENSIONS = {
    ".py", ".rb", ".ts", ".js", ".rs", ".go", ".dart", ".php", ".lua",
    ".kt", ".swift", ".nim", ".zig", ".hs", ".elm", ".cr", ".jl",
    ".re", ".resi", ".imba", ".mjo", ".c", ".h", ".cpp", ".hpp", ".cc",
    ".cxx", ".hh", ".hxx", ".java", ".scala", ".ex", ".exs", ".ml", ".mli",
}


def _is_excluded(path: Path, root: Path) -> bool:
    try:
        rel = path.relative_to(root)
    except ValueError:
        return True

    for part in rel.parts:
        if part in EXCLUDED_DIRS:
            return True
    return False


def _iter_source_files(root: Path) -> Iterable[Path]:
    for file_path in root.rglob("*"):
        if not file_path.is_file():
            continue
        if _is_excluded(file_path, root):
            continue
        if file_path.suffix.lower() in SOURCE_EXTENSIONS:
            yield file_path


def collect_metrics_for_impl(impl_path: Path) -> Dict:
    source_files = list(_iter_source_files(impl_path))
    source_loc = 0

    for source_file in source_files:
        try:
            source_loc += len(source_file.read_text(encoding="utf-8", errors="ignore").splitlines())
        except Exception:
            continue

    return {
        "implementation": impl_path.name,
        "path": str(impl_path),
        "source_files": len(source_files),
        "source_loc": source_loc,
    }


def collect_metrics_for_dir(base_dir: Path) -> List[Dict]:
    metrics = []
    for impl_path in sorted(base_dir.iterdir()):
        if not impl_path.is_dir():
            continue
        if not (impl_path / "Dockerfile").exists():
            continue
        metrics.append(collect_metrics_for_impl(impl_path))
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(description="Collect normalized code size metrics")
    parser.add_argument("--impl", metavar="PATH", help="Single implementation path")
    parser.add_argument("--dir", default="implementations", metavar="DIR", help="Implementations directory")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")

    args = parser.parse_args()

    if args.impl:
        impl_path = Path(args.impl)
        if not impl_path.exists() or not impl_path.is_dir():
            print(json.dumps({"error": f"Implementation path not found: {impl_path}"}))
            return 1
        payload = collect_metrics_for_impl(impl_path)
    else:
        base_dir = Path(args.dir)
        if not base_dir.exists() or not base_dir.is_dir():
            print(json.dumps({"error": f"Directory not found: {base_dir}"}))
            return 1
        payload = collect_metrics_for_dir(base_dir)

    indent = 2 if args.pretty else None
    print(json.dumps(payload, indent=indent))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
