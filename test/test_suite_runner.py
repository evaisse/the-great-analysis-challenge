#!/usr/bin/env python3
"""Run test/test_suite.json against implementations via Docker."""

import argparse
import json
import os
import sys
import time
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
TEST_SUITE_PATH = REPO_ROOT / "test" / "test_suite.json"


def load_test_suite() -> Dict[str, Any]:
    if not TEST_SUITE_PATH.exists():
        raise FileNotFoundError(f"Test suite not found: {TEST_SUITE_PATH}")
    with TEST_SUITE_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_metadata(impl_path: Path) -> Dict[str, Any]:
    meta_path = impl_path / "chess.meta"
    if not meta_path.exists():
        raise FileNotFoundError(f"Missing chess.meta: {meta_path}")
    with meta_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def discover_implementations(base_dir: Path) -> List[Path]:
    if not base_dir.exists():
        return []
    implementations = []
    for entry in sorted(base_dir.iterdir()):
        if entry.is_dir() and (entry / "chess.meta").exists():
            implementations.append(entry)
    return implementations


def build_test_list(suite: Dict[str, Any], level: str) -> List[Dict[str, Any]]:
    compliance = suite.get("compliance_levels", {})
    if level not in compliance:
        raise ValueError(f"Unknown compliance level: {level}")
    required_categories = compliance[level].get("required_categories", [])

    test_categories = suite.get("test_categories", {})
    ordered_tests: List[Dict[str, Any]] = []
    for category_name, category in test_categories.items():
        if category_name not in required_categories:
            continue
        for test in category.get("tests", []):
            test_copy = dict(test)
            test_copy["category"] = category_name
            ordered_tests.append(test_copy)
    return ordered_tests


def run_test(image_tag: str, run_cmd: str, test: Dict[str, Any]) -> Dict[str, Any]:
    commands = [cmd["cmd"] for cmd in test.get("commands", [])]
    input_text = "\n".join(commands) + "\n"

    timeout_ms = int(test.get("timeout", 10000))
    timeout_sec = max(1.0, timeout_ms / 1000.0)

    docker_cmd = [
        "docker",
        "run",
        "--rm",
        "-i",
        image_tag,
        "sh",
        "-c",
        f"cd /app && {run_cmd}",
    ]

    start = time.perf_counter()
    try:
        result = subprocess.run(
            docker_cmd,
            input=input_text,
            capture_output=True,
            text=True,
            timeout=timeout_sec + 2.0,
        )
        elapsed_ms = int((time.perf_counter() - start) * 1000)
    except subprocess.TimeoutExpired:
        elapsed_ms = int((time.perf_counter() - start) * 1000)
        return {
            "id": test.get("id"),
            "name": test.get("name"),
            "category": test.get("category"),
            "passed": False,
            "elapsed_ms": elapsed_ms,
            "timeout_ms": timeout_ms,
            "error": "timeout",
            "output": "",
            "expected_patterns": test.get("expected_patterns", []),
            "matched_patterns": [],
        }

    output = (result.stdout or "")
    if result.stderr:
        output = output + "\n" + result.stderr

    expected_patterns = test.get("expected_patterns", [])
    matched = [pattern for pattern in expected_patterns if pattern in output]
    passed = len(matched) == len(expected_patterns)

    if test.get("measure_time") and "max_time" in test:
        max_time = int(test["max_time"])
        if elapsed_ms > max_time:
            passed = False

    return {
        "id": test.get("id"),
        "name": test.get("name"),
        "category": test.get("category"),
        "passed": passed,
        "elapsed_ms": elapsed_ms,
        "timeout_ms": timeout_ms,
        "exit_code": result.returncode,
        "expected_patterns": expected_patterns,
        "matched_patterns": matched,
        "output": output[:2000],
    }


def run_suite_for_impl(impl_path: Path, level: str, output_dir: Path) -> Dict[str, Any]:
    metadata = load_metadata(impl_path)
    run_cmd = metadata.get("run")
    if not run_cmd:
        raise ValueError(f"Missing run command in chess.meta for {impl_path}")

    suite = load_test_suite()
    tests = build_test_list(suite, level)

    impl_name = impl_path.name
    image_tag = f"chess-{impl_name}"

    results: List[Dict[str, Any]] = []
    failures = 0

    print(f"\n=== Running test suite for {impl_name} ({level}) ===")
    for test in tests:
        print(f"- {test.get('category')}: {test.get('name')}")
        result = run_test(image_tag, run_cmd, test)
        results.append(result)

        status = "PASS" if result["passed"] else "FAIL"
        print(f"  {status} ({result['elapsed_ms']}ms)")
        if not result["passed"]:
            failures += 1

    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / f"{impl_name}.json"
    report = {
        "implementation": impl_name,
        "level": level,
        "image": image_tag,
        "run": run_cmd,
        "tests": results,
        "failures": failures,
        "timestamp": int(time.time()),
    }
    with report_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)

    print(f"Report: {report_path}")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description="Run test/test_suite.json against implementations")
    parser.add_argument("--impl", help="Implementation path (e.g., implementations/python)")
    parser.add_argument("--dir", default="implementations", help="Base implementations directory")
    parser.add_argument("--level", default="advanced", help="Compliance level: basic|standard|advanced")
    parser.add_argument(
        "--output-dir",
        default="reports/test_suite",
        help="Output directory for JSON reports",
    )

    args = parser.parse_args()

    output_dir = REPO_ROOT / args.output_dir

    if args.impl:
        impl_paths = [Path(args.impl)]
    else:
        impl_paths = discover_implementations(REPO_ROOT / args.dir)

    if not impl_paths:
        print("No implementations found.")
        return 1

    overall_failures = 0
    for impl_path in impl_paths:
        report = run_suite_for_impl(impl_path, args.level, output_dir)
        overall_failures += report["failures"]

    if overall_failures > 0:
        print(f"\nFAILED: {overall_failures} test(s) failed")
        return 1

    print("\nSUCCESS: All tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
