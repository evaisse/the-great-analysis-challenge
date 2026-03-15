#!/usr/bin/env python3
"""Run a metadata phase command inside an existing implementation Docker image."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import subprocess
import sys
from pathlib import Path

# Ensure scripts directory is importable when called from repository root.
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from chess_metadata import get_metadata

TRUTHY_VALUES = {"1", "true", "yes", "y", "on"}
SKIP_VALUES = {"skip", "skipped"}
INTERPRETED_RUNTIME_VALUES = {"interpreted", "scripted", "jit"}


@dataclass
class PhaseExecution:
    impl_name: str
    phase: str
    command: str
    returncode: int
    stdout: str
    stderr: str
    skipped: bool = False
    skip_reason: str | None = None


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


def _run_with_shell(
    image: str, shell: str, command: str, workdir: Path | None = None
) -> subprocess.CompletedProcess:
    docker_cmd = [
        "docker",
        "run",
        "--rm",
        "--network",
        "none",
        "--entrypoint",
        shell,
    ]
    if workdir is not None:
        docker_cmd.extend(["-v", f"{workdir.resolve()}:/app"])
    docker_cmd.extend([image, "-c", f"cd /app && {command}"])
    return subprocess.run(
        docker_cmd,
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


def _should_skip_build_phase(metadata: dict) -> bool:
    benchmark_build = str(metadata.get("benchmark.build", "")).strip().lower()
    if benchmark_build in SKIP_VALUES or benchmark_build in TRUTHY_VALUES:
        return True

    runtime_mode = str(metadata.get("runtime", "")).strip().lower()
    return runtime_mode in INTERPRETED_RUNTIME_VALUES


def execute_phase(
    impl: str | Path,
    phase: str,
    image: str | None = None,
    workdir: str | Path | None = None,
) -> PhaseExecution:
    impl_path = resolve_impl_path(str(impl))
    impl_name = impl_path.name
    image_name = image or f"chess-{impl_name}"
    metadata = get_metadata(str(impl_path))

    if phase == "build" and _should_skip_build_phase(metadata):
        return PhaseExecution(
            impl_name=impl_name,
            phase=phase,
            command="",
            returncode=0,
            stdout="",
            stderr="",
            skipped=True,
            skip_reason=f"Skipping build phase for {impl_name} (metadata benchmark/runtime flag)",
        )

    command = str(metadata.get(phase, "")).strip()
    if not command:
        raise ValueError(
            f"Missing metadata command 'org.chess.{phase}' for {impl_name}"
        )

    if not docker_image_exists(image_name):
        raise FileNotFoundError(
            f"Docker image '{image_name}' not found. Run: make image DIR={impl_name}"
        )

    mounted_workdir = None
    if workdir is not None:
        mounted_workdir = Path(workdir).resolve()
        if not mounted_workdir.exists():
            raise FileNotFoundError(f"Workspace not found: {mounted_workdir}")

    result = _run_with_shell(image_name, "sh", command, mounted_workdir)
    if result.returncode != 0 and _shell_missing(result.stderr, "sh"):
        result = _run_with_shell(image_name, "bash", command, mounted_workdir)

    return PhaseExecution(
        impl_name=impl_name,
        phase=phase,
        command=command,
        returncode=result.returncode,
        stdout=result.stdout or "",
        stderr=result.stderr or "",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a metadata phase in Docker")
    parser.add_argument("--impl", required=True, help="Implementation name or path")
    parser.add_argument(
        "--phase",
        required=True,
        choices=["build", "analyze", "test", "bugit", "fix"],
        help="Metadata field to execute",
    )
    parser.add_argument("--image", help="Docker image name (defaults to chess-<impl>)")
    parser.add_argument(
        "--workdir",
        help="Optional host workspace mounted at /app instead of the image filesystem",
    )
    args = parser.parse_args()

    try:
        execution = execute_phase(
            impl=args.impl,
            phase=args.phase,
            image=args.image,
            workdir=args.workdir,
        )
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if execution.skipped:
        print(execution.skip_reason)
        return 0

    location_hint = "workspace mount" if args.workdir else "Docker image"
    print(f"Running {args.phase} for {execution.impl_name} in {location_hint}...")
    print(f"Command: {execution.command}")

    if execution.stdout:
        sys.stdout.write(execution.stdout)
    if execution.stderr:
        sys.stderr.write(execution.stderr)

    return execution.returncode


if __name__ == "__main__":
    raise SystemExit(main())
