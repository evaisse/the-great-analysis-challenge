#!/usr/bin/env python3
"""Shared helpers for implementation size and token metrics."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Sequence

TOKEN_METRIC_VERSION = "tokens-v2"

# Language-agnostic tokenizer:
# - identifiers
# - integer/decimal numbers
# - common multi-char operators
# - punctuation/single-char operators
# - fallback on any non-whitespace symbol
TOKEN_PATTERN = re.compile(
    r"[A-Za-z_][A-Za-z0-9_]*"
    r"|\d+(?:\.\d+)?"
    r"|==|!=|<=|>=|<<|>>|&&|\|\||::|->|=>|\+\+|--|\+=|-=|\*=|/=|%=|&=|\|=|\^=|//="
    r"|[{}()\[\].,;:?+\-*/%&|^~<>!=]"
    r"|\S"
)


def parse_source_exts(raw_value: object) -> List[str]:
    """Normalize source extension declarations to a deduplicated lower-case list."""
    if raw_value is None:
        return []

    if isinstance(raw_value, str):
        items = [part.strip() for part in raw_value.split(",")]
    elif isinstance(raw_value, (list, tuple, set)):
        items = [str(part).strip() for part in raw_value]
    else:
        return []

    normalized: List[str] = []
    seen = set()
    for item in items:
        if not item:
            continue
        extension = item if item.startswith(".") else f".{item}"
        extension = extension.lower()
        if extension in seen:
            continue
        seen.add(extension)
        normalized.append(extension)
    return normalized


def normalize_line_endings(text: str) -> str:
    """Normalize CRLF/CR line endings to LF."""
    return text.replace("\r\n", "\n").replace("\r", "\n")


def count_tokens(text: str) -> int:
    """Count tokens using the language-agnostic regex."""
    normalized = normalize_line_endings(text)
    return len(TOKEN_PATTERN.findall(normalized))


def _find_repo_root(start_path: Path) -> Optional[Path]:
    """Find repository root by walking parent directories until .git is found."""
    current = start_path.resolve()
    if current.is_file():
        current = current.parent

    for candidate in [current, *current.parents]:
        if (candidate / ".git").exists():
            return candidate
    return None


def list_git_discovered_files(impl_path: Path) -> List[Path]:
    """List tracked + untracked files (excluding ignored) for an implementation."""
    repo_root = _find_repo_root(impl_path)
    if repo_root is None:
        raise RuntimeError(f"Could not locate git repository root for {impl_path}")

    impl_abs = impl_path.resolve()
    try:
        rel_impl = impl_abs.relative_to(repo_root)
    except ValueError as exc:
        raise RuntimeError(f"Implementation path {impl_abs} is outside repository root {repo_root}") from exc

    result = subprocess.run(
        ["git", "-C", str(repo_root), "ls-files", "-co", "--exclude-standard", "--", str(rel_impl)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise RuntimeError(f"git ls-files failed for {rel_impl}: {stderr or 'unknown error'}")

    files: List[Path] = []
    for line in sorted(line.strip() for line in result.stdout.splitlines() if line.strip()):
        candidate = (repo_root / line).resolve()
        if candidate.is_file():
            files.append(candidate)
    return files


def _is_probably_binary(file_path: Path) -> bool:
    """Return True if file appears binary based on NUL-byte probe."""
    try:
        with open(file_path, "rb") as handle:
            return b"\x00" in handle.read(8192)
    except OSError:
        return True


def _read_text_file(file_path: Path) -> Optional[str]:
    """Read UTF-8 text content, skipping unreadable/binary files safely."""
    if _is_probably_binary(file_path):
        return None
    try:
        return file_path.read_text(encoding="utf-8", errors="ignore")
    except (OSError, UnicodeError):
        return None


def collect_impl_metrics(impl_path: Path, source_exts: Sequence[str]) -> Dict[str, object]:
    """Collect LOC + token metrics for one implementation using git-discovered files."""
    normalized_exts = parse_source_exts(source_exts)
    if not normalized_exts:
        raise ValueError(f"No valid source extensions configured for {impl_path}")

    source_files = 0
    source_loc = 0
    tokens_count = 0
    skipped_binary_or_unreadable = 0

    for file_path in list_git_discovered_files(impl_path):
        if file_path.suffix.lower() not in normalized_exts:
            continue

        text = _read_text_file(file_path)
        if text is None:
            skipped_binary_or_unreadable += 1
            continue

        normalized = normalize_line_endings(text)
        source_files += 1
        source_loc += len(normalized.splitlines())
        tokens_count += count_tokens(normalized)

    return {
        "implementation": impl_path.name,
        "path": str(impl_path),
        "source_exts": normalized_exts,
        "source_files": source_files,
        "source_loc": source_loc,
        "tokens_count": tokens_count,
        "metric_version": TOKEN_METRIC_VERSION,
        "skipped_binary_or_unreadable": skipped_binary_or_unreadable,
    }


def collect_impl_metrics_from_metadata(impl_path: Path, metadata: Dict[str, object]) -> Dict[str, object]:
    """Collect metrics by reading source extension declarations from metadata."""
    source_exts = parse_source_exts(metadata.get("source_exts"))
    return collect_impl_metrics(impl_path, source_exts)
