#!/usr/bin/env python3
"""
Static analysis helper for Python tooling that lives outside language implementations.

The goal is to catch syntax errors early in supporting scripts (workflow helpers,
test harnesses, build tooling, etc.) without touching implementation-specific code
that already has its own Docker-driven checks.
"""

from __future__ import annotations

import sys
import tokenize
from pathlib import Path
from typing import Iterable, Set, Tuple


EXCLUDED_DIR_NAMES: Set[str] = {
    "implementations",
    "__pycache__",
    ".git",
    "reports",
    "docs",  # Generated website assets; no maintained Python sources here
    "benchmark_reports",
}

# Python entry points without a .py extension that we still want to check.
EXTRA_FILES: Tuple[str, ...] = (
    "workflow",
)


def iter_python_files(root: Path) -> Iterable[Path]:
    """Yield Python source files to check, skipping implementation-specific paths."""
    for path in root.rglob("*.py"):
        try:
            relative_parts = path.relative_to(root).parts
        except ValueError:
            continue

        if any(part in EXCLUDED_DIR_NAMES for part in relative_parts):
            continue

        yield path

    for extra in EXTRA_FILES:
        extra_path = root / extra
        if extra_path.exists() and extra_path.is_file():
            yield extra_path


def compile_python_file(path: Path) -> None:
    """Compile a Python file to bytecode without writing .pyc artifacts."""
    with tokenize.open(path) as handle:
        source = handle.read()
    compile(source, str(path), "exec")


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    failures = []
    checked_files = []

    for py_file in sorted(set(iter_python_files(repo_root))):
        try:
            compile_python_file(py_file)
            checked_files.append(py_file)
        except SyntaxError as exc:
            message = f"{exc.msg} (line {exc.lineno})"
            failures.append((py_file, message))
        except Exception as exc:  # noqa: BLE001 - surface unexpected issues clearly
            failures.append((py_file, str(exc)))

    if failures:
        print("❌ Python tooling static analysis failed:")
        for path, message in failures:
            print(f"  - {path}: {message}")
        print(f"\nChecked {len(checked_files) + len(failures)} file(s); {len(failures)} failure(s).")
        return 1

    print(f"✅ Python tooling static analysis passed on {len(checked_files)} file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

