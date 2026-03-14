#!/usr/bin/env python3
"""Benchmark static-analysis behavior against an injected implementation bug."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from run_metadata_phase import PhaseExecution, docker_image_exists, execute_phase, resolve_impl_path

WORKSPACE_ROOT = REPO_ROOT / "reports" / "error-analysis-workspaces"
REPORT_ROOT = REPO_ROOT / "reports" / "error-analysis"


def default_workspace_path(impl_name: str) -> Path:
    return WORKSPACE_ROOT / impl_name


def default_report_json_path(impl_name: str) -> Path:
    return REPORT_ROOT / f"{impl_name}.json"


def default_report_text_path(impl_name: str) -> Path:
    return REPORT_ROOT / f"{impl_name}.txt"


def ensure_image_exists(image: str, impl_name: str) -> None:
    if not docker_image_exists(image):
        raise FileNotFoundError(
            f"Docker image '{image}' not found. Run: make image DIR={impl_name}"
        )


def seed_workspace(image: str, workspace: Path) -> None:
    if workspace.exists():
        shutil.rmtree(workspace)
    workspace.parent.mkdir(parents=True, exist_ok=True)
    workspace.mkdir(parents=True, exist_ok=True)

    created = subprocess.run(
        ["docker", "create", image],
        check=True,
        text=True,
        capture_output=True,
    )
    container_id = created.stdout.strip()
    try:
        subprocess.run(
            ["docker", "cp", f"{container_id}:/app/.", str(workspace)],
            check=True,
            text=True,
            capture_output=True,
        )
    finally:
        subprocess.run(
            ["docker", "rm", "-f", container_id],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def record_phase(
    impl_path: Path, phase: str, image: str, workspace: Path
) -> dict[str, object]:
    started = time.perf_counter()
    execution = execute_phase(impl=str(impl_path), phase=phase, image=image, workdir=workspace)
    duration_s = time.perf_counter() - started
    return execution_to_dict(execution, duration_s)


def execution_to_dict(execution: PhaseExecution, duration_s: float | None = None) -> dict[str, object]:
    payload: dict[str, object] = {
        "phase": execution.phase,
        "command": execution.command,
        "returncode": execution.returncode,
        "success": execution.returncode == 0,
        "skipped": execution.skipped,
        "skip_reason": execution.skip_reason,
        "stdout": execution.stdout,
        "stderr": execution.stderr,
    }
    if duration_s is not None:
        payload["duration_s"] = round(duration_s, 6)
    return payload


def build_text_report(report: dict[str, object]) -> str:
    summary = report["summary"]
    phases = report["phases"]
    lines = [
        "ERROR ANALYSIS BENCHMARK REPORT",
        "=" * 80,
        f"Implementation: {report['implementation']}",
        f"Image: {report['image']}",
        f"Workspace: {report['workspace']}",
        f"Generated: {report['generated_at']}",
        "",
        "SUMMARY",
        "-" * 80,
        f"Bug injected: {summary['bugit_success']}",
        f"Analyzer detected bug: {summary['bug_detected']}",
        f"Fix applied: {summary['fix_success']}",
        f"Analyzer green after fix: {summary['recovered']}",
        "",
        "PHASES",
        "-" * 80,
    ]

    for name, phase in phases.items():
        lines.append(
            f"{name}: success={phase['success']} returncode={phase['returncode']} duration_s={phase.get('duration_s', 0)}"
        )
        lines.append(f"  command: {phase['command']}")

    lines.extend(
        [
            "",
            "ANALYZE WITH BUG STDERR",
            "-" * 80,
            str(phases["analyze_with_bug"]["stderr"]).rstrip() or "(empty)",
            "",
            "ANALYZE WITH BUG STDOUT",
            "-" * 80,
            str(phases["analyze_with_bug"]["stdout"]).rstrip() or "(empty)",
            "",
            "ANALYZE AFTER FIX STDERR",
            "-" * 80,
            str(phases["analyze_after_fix"]["stderr"]).rstrip() or "(empty)",
            "",
            "ANALYZE AFTER FIX STDOUT",
            "-" * 80,
            str(phases["analyze_after_fix"]["stdout"]).rstrip() or "(empty)",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


def write_report(report: dict[str, object], json_path: Path, text_path: Path) -> None:
    json_path.parent.mkdir(parents=True, exist_ok=True)
    text_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    text_path.write_text(build_text_report(report), encoding="utf-8")


def run_prepare(impl_path: Path, image: str, workspace: Path) -> int:
    ensure_image_exists(image, impl_path.name)
    seed_workspace(image, workspace)
    print(f"Prepared workspace for {impl_path.name}: {workspace}")
    return 0


def run_bugit(impl_path: Path, image: str, workspace: Path, reset_workspace: bool) -> int:
    ensure_image_exists(image, impl_path.name)
    if reset_workspace or not workspace.exists():
        seed_workspace(image, workspace)
    phase = record_phase(impl_path, "bugit", image, workspace)
    if phase["stdout"]:
        sys.stdout.write(str(phase["stdout"]))
    if phase["stderr"]:
        sys.stderr.write(str(phase["stderr"]))
    return int(phase["returncode"])


def run_fix(impl_path: Path, image: str, workspace: Path) -> int:
    ensure_image_exists(image, impl_path.name)
    if not workspace.exists():
        print(f"No workspace to fix for {impl_path.name}: {workspace}")
        return 0
    phase = record_phase(impl_path, "fix", image, workspace)
    if phase["stdout"]:
        sys.stdout.write(str(phase["stdout"]))
    if phase["stderr"]:
        sys.stderr.write(str(phase["stderr"]))
    return int(phase["returncode"])


def run_benchmark(
    impl_path: Path,
    image: str,
    workspace: Path,
    json_path: Path,
    text_path: Path,
) -> int:
    ensure_image_exists(image, impl_path.name)
    seed_workspace(image, workspace)

    bugit_phase = record_phase(impl_path, "bugit", image, workspace)
    analyze_with_bug = record_phase(impl_path, "analyze", image, workspace)
    fix_phase = record_phase(impl_path, "fix", image, workspace)
    analyze_after_fix = record_phase(impl_path, "analyze", image, workspace)

    report = {
        "implementation": impl_path.name,
        "image": image,
        "workspace": str(workspace),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "phases": {
            "bugit": bugit_phase,
            "analyze_with_bug": analyze_with_bug,
            "fix": fix_phase,
            "analyze_after_fix": analyze_after_fix,
        },
        "summary": {
            "bugit_success": bool(bugit_phase["success"]),
            "bug_detected": not bool(analyze_with_bug["success"]),
            "fix_success": bool(fix_phase["success"]),
            "recovered": bool(analyze_after_fix["success"]),
        },
    }
    write_report(report, json_path, text_path)

    print(f"JSON report: {json_path}")
    print(f"Text report: {text_path}")
    print(
        "Summary: "
        f"bugit_success={report['summary']['bugit_success']} "
        f"bug_detected={report['summary']['bug_detected']} "
        f"fix_success={report['summary']['fix_success']} "
        f"recovered={report['summary']['recovered']}"
    )

    return 0 if (
        report["summary"]["bugit_success"]
        and report["summary"]["bug_detected"]
        and report["summary"]["fix_success"]
        and report["summary"]["recovered"]
    ) else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Prepare or benchmark reproducible static-analysis bug injection workspaces"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_common_args(subparser: argparse.ArgumentParser) -> None:
        subparser.add_argument("--impl", required=True, help="Implementation name or path")
        subparser.add_argument("--image", help="Docker image name (defaults to chess-<impl>)")
        subparser.add_argument(
            "--workspace",
            help="Workspace path (defaults to reports/error-analysis-workspaces/<impl>)",
        )

    prepare = subparsers.add_parser("prepare", help="Seed a workspace from the Docker image")
    add_common_args(prepare)

    bugit = subparsers.add_parser("bugit", help="Inject the configured benchmark bug")
    add_common_args(bugit)
    bugit.add_argument(
        "--reset-workspace",
        action="store_true",
        help="Reseed the workspace from the image before injecting the bug",
    )

    fix = subparsers.add_parser("fix", help="Restore the configured benchmark bug")
    add_common_args(fix)

    benchmark = subparsers.add_parser(
        "benchmark",
        help="Run bug injection, analyze the failure, repair it, and analyze again",
    )
    add_common_args(benchmark)
    benchmark.add_argument(
        "--report-json",
        help="JSON report path (defaults to reports/error-analysis/<impl>.json)",
    )
    benchmark.add_argument(
        "--report-text",
        help="Text report path (defaults to reports/error-analysis/<impl>.txt)",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        impl_path = resolve_impl_path(args.impl)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    image = args.image or f"chess-{impl_path.name}"
    workspace = Path(args.workspace).resolve() if args.workspace else default_workspace_path(impl_path.name)
    json_path = (
        Path(args.report_json).resolve()
        if getattr(args, "report_json", None)
        else default_report_json_path(impl_path.name)
    )
    text_path = (
        Path(args.report_text).resolve()
        if getattr(args, "report_text", None)
        else default_report_text_path(impl_path.name)
    )

    try:
        if args.command == "prepare":
            return run_prepare(impl_path, image, workspace)
        if args.command == "bugit":
            return run_bugit(impl_path, image, workspace, args.reset_workspace)
        if args.command == "fix":
            return run_fix(impl_path, image, workspace)
        if args.command == "benchmark":
            return run_benchmark(impl_path, image, workspace, json_path, text_path)
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip() if exc.stderr else str(exc)
        print(f"ERROR: {stderr}", file=sys.stderr)
        return exc.returncode or 1
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    parser.error(f"Unsupported command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
