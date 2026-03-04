#!/usr/bin/env python3
"""Run a metadata phase command inside an existing implementation Docker image."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

# Ensure scripts directory is importable when called from repository root.
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from chess_metadata import get_metadata


def resolve_impl_path(impl: str) -> Path:
    candidate = Path(impl)
    if candidate.exists():
        return candidate.resolve()

    fallback = Path("implementations") / impl
    if fallback.exists():
        return fallback.resolve()

    raise FileNotFoundError(f"Implementation not found: {impl}")


def docker_image_exists(image: str) -> bool:
    result = subprocess.run(
        ["docker", "image", "inspect", image],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def _run_with_shell(image: str, shell: str, command: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            image,
            shell,
            "-c",
            f"cd /app && {command}",
        ],
        check=False,
        text=True,
        capture_output=True,
    )


def _shell_missing(stderr: str | None, shell: str) -> bool:
    if not stderr:
        return False
    stderr_lower = stderr.lower()
    return shell in stderr_lower and (
        "executable file not found in $path" in stderr_lower
        or "no such file or directory" in stderr_lower
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a metadata phase in Docker")
    parser.add_argument("--impl", required=True, help="Implementation name or path")
    parser.add_argument(
        "--phase",
        required=True,
        choices=["build", "analyze", "test"],
        help="Metadata field to execute",
    )
    parser.add_argument("--image", help="Docker image name (defaults to chess-<impl>)")
    args = parser.parse_args()

    try:
        impl_path = resolve_impl_path(args.impl)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    impl_name = impl_path.name
    image = args.image or f"chess-{impl_name}"

    metadata = get_metadata(str(impl_path))
    command = metadata.get(args.phase, "")

    if not command:
        print(
            f"ERROR: Missing metadata command 'org.chess.{args.phase}' for {impl_name}",
            file=sys.stderr,
        )
        return 1

    if not docker_image_exists(image):
        print(
            f"ERROR: Docker image '{image}' not found. Run: make image DIR={impl_name}",
            file=sys.stderr,
        )
        return 1

    print(f"Running {args.phase} for {impl_name} in Docker...")
    print(f"Command: {command}")

    # Use non-login shell execution (-c) so image PATH is preserved.
    # Try sh first for maximum compatibility with runtime entrypoints, then fall back to bash.
    result = _run_with_shell(image, "sh", command)
    if result.returncode != 0 and _shell_missing(result.stderr, "sh"):
        result = _run_with_shell(image, "bash", command)

    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)

    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
