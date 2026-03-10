#!/usr/bin/env python3
"""Collect implementation code size and token metrics."""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List

# Ensure repository root is importable.
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

# Import shared helpers from scripts/.
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from chess_metadata import get_metadata
from token_metrics import collect_impl_metrics_from_metadata


def collect_metrics_for_impl(impl_path: Path) -> Dict:
    metadata = get_metadata(str(impl_path))
    metrics = collect_impl_metrics_from_metadata(impl_path, metadata)
    return {
        "implementation": metrics["implementation"],
        "path": metrics["path"],
        "source_files": metrics["source_files"],
        "source_loc": metrics["source_loc"],
        "tokens_count": metrics["tokens_count"],
        "metric_version": metrics["metric_version"],
        "source_exts": metrics["source_exts"],
        "skipped_binary_or_unreadable": metrics["skipped_binary_or_unreadable"],
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
    parser = argparse.ArgumentParser(description="Collect implementation code size and token metrics")
    parser.add_argument("--impl", metavar="PATH", help="Single implementation path")
    parser.add_argument("--dir", default="implementations", metavar="DIR", help="Implementations directory")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")

    args = parser.parse_args()

    try:
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
    except Exception as exc:
        print(json.dumps({"error": str(exc)}))
        return 1

    indent = 2 if args.pretty else None
    print(json.dumps(payload, indent=indent))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
