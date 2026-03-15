#!/usr/bin/env python3
"""Run shared unit-contract suites against implementation-provided adapters."""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
import tempfile
from collections.abc import Sequence
from pathlib import Path
from typing import Any, Dict, List, Tuple

# Ensure repository root is importable.
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from chess_metadata import get_metadata

DEFAULT_SUITE = REPO_ROOT / "test" / "contracts" / "unit_v1.json"
DEFAULT_PROTOCOL_SUITE = REPO_ROOT / "test" / "test_suite.json"
CONTAINER_REPO_ROOT = Path("/repo")

SUPPORTED_COMPARE_TYPES = {
    "fen_exact",
    "integer_exact",
    "move_exact",
    "move_set_exact",
    "status_exact",
    "string_exact",
}
SUPPORTED_SETUP_TYPES = {"new_game", "fen"}
SUPPORTED_OPERATION_TYPES = {
    "export_fen",
    "legal_move_count",
    "apply_move_export_fen",
    "apply_move_undo_export_fen",
    "apply_move_status",
    "ai_best_move",
}
VALID_CASE_STATUSES = {"passed", "failed", "skipped"}


def resolve_impl_path(impl: str) -> Path:
    candidate = Path(impl)
    if candidate.exists():
        return candidate.resolve()

    fallback = REPO_ROOT / "implementations" / impl
    if fallback.exists():
        return fallback.resolve()

    raise FileNotFoundError(f"Implementation not found: {impl}")


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_contract_suite(suite: Dict[str, Any]) -> List[str]:
    errors: List[str] = []

    if suite.get("schema_version") != "1.0":
        errors.append("Contract suite schema_version must be '1.0'")
    if not isinstance(suite.get("suite"), str) or not suite["suite"].strip():
        errors.append("Contract suite must define a non-empty 'suite' name")

    declared_required_features = suite.get("required_features", [])
    if declared_required_features and not isinstance(declared_required_features, list):
        errors.append("Contract suite 'required_features' must be a list when present")
    elif declared_required_features:
        for feature in declared_required_features:
            if not isinstance(feature, str) or not feature.strip():
                errors.append("Contract suite required_features entries must be non-empty strings")

    cases = suite.get("cases")
    if not isinstance(cases, list) or not cases:
        errors.append("Contract suite must contain a non-empty 'cases' list")
        return errors

    seen_ids = set()
    seen_required_features = set()
    for index, case in enumerate(cases, start=1):
        case_label = f"case #{index}"
        if not isinstance(case, dict):
            errors.append(f"{case_label} must be an object")
            continue

        missing_keys = {
            "id",
            "feature",
            "required",
            "setup",
            "operation",
            "expect",
            "compare",
        } - set(case.keys())
        if missing_keys:
            errors.append(f"{case_label} missing keys: {', '.join(sorted(missing_keys))}")
            continue

        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id.strip():
            errors.append(f"{case_label} has an invalid 'id'")
        elif case_id in seen_ids:
            errors.append(f"Duplicate contract case id: {case_id}")
        else:
            seen_ids.add(case_id)

        feature = case.get("feature")
        if not isinstance(feature, str) or not feature.strip():
            errors.append(f"{case_label} has an invalid 'feature'")
        elif case.get("required"):
            seen_required_features.add(feature)

        if not isinstance(case.get("required"), bool):
            errors.append(f"{case_label} 'required' must be a boolean")

        setup = case.get("setup")
        if not isinstance(setup, dict):
            errors.append(f"{case_label} 'setup' must be an object")
        else:
            setup_type = setup.get("type")
            if setup_type not in SUPPORTED_SETUP_TYPES:
                errors.append(
                    f"{case_label} has unsupported setup type '{setup_type}'"
                )
            if setup_type == "fen" and not isinstance(setup.get("value"), str):
                errors.append(f"{case_label} fen setup must include string 'value'")

        operation = case.get("operation")
        if not isinstance(operation, dict):
            errors.append(f"{case_label} 'operation' must be an object")
        else:
            op_type = operation.get("type")
            if op_type not in SUPPORTED_OPERATION_TYPES:
                errors.append(
                    f"{case_label} has unsupported operation type '{op_type}'"
                )
            if op_type in {
                "apply_move_export_fen",
                "apply_move_undo_export_fen",
                "apply_move_status",
            } and not isinstance(operation.get("move"), str):
                errors.append(f"{case_label} move operation must include string 'move'")
            if op_type == "ai_best_move" and not isinstance(operation.get("depth"), int):
                errors.append(f"{case_label} ai_best_move must include integer 'depth'")

        expect = case.get("expect")
        if not isinstance(expect, dict) or "value" not in expect:
            errors.append(f"{case_label} 'expect' must be an object containing 'value'")

        compare = case.get("compare")
        if compare not in SUPPORTED_COMPARE_TYPES:
            errors.append(f"{case_label} has unsupported compare mode '{compare}'")

    if isinstance(declared_required_features, list) and declared_required_features:
        declared_feature_set = set(declared_required_features)
        if declared_feature_set != seen_required_features:
            errors.append(
                "Contract suite required_features must match the feature set of required cases"
            )

    return errors


def extract_protocol_features(protocol_suite: Dict[str, Any]) -> Tuple[set[str], List[str]]:
    features: set[str] = set()
    errors: List[str] = []

    categories = protocol_suite.get("test_categories", {})
    if not isinstance(categories, dict):
        return features, ["Protocol suite must contain 'test_categories' object"]

    for category_id, category in categories.items():
        if not isinstance(category, dict) or not category.get("required", False):
            continue
        tests = category.get("tests", [])
        if not isinstance(tests, list):
            errors.append(f"Protocol category '{category_id}' tests must be a list")
            continue
        for test in tests:
            test_id = test.get("id", "<unknown>")
            feature = test.get("feature")
            if not isinstance(feature, str) or not feature.strip():
                errors.append(
                    f"Required protocol test '{test_id}' in category '{category_id}' is missing a feature annotation"
                )
                continue
            features.add(feature)

    return features, errors


def lint_feature_vocabulary(
    contract_suite: Dict[str, Any],
    protocol_suite: Dict[str, Any],
) -> List[str]:
    errors: List[str] = []

    declared_required = contract_suite.get("required_features") or []
    unit_features = (
        set(declared_required)
        if declared_required
        else {
            case["feature"]
            for case in contract_suite.get("cases", [])
            if isinstance(case, dict) and case.get("required")
        }
    )

    protocol_features, protocol_errors = extract_protocol_features(protocol_suite)
    errors.extend(protocol_errors)

    missing_in_protocol = sorted(unit_features - protocol_features)
    if missing_in_protocol:
        errors.append(
            "Required unit-contract features missing from protocol suite: "
            + ", ".join(missing_in_protocol)
        )

    missing_in_contract = sorted(protocol_features - unit_features)
    if missing_in_contract:
        errors.append(
            "Required protocol-suite features missing from unit contract suite: "
            + ", ".join(missing_in_contract)
        )

    return errors


def normalize_value(compare: str, value: Any) -> Any:
    if compare == "fen_exact":
        return " ".join(str(value).strip().split())
    if compare == "integer_exact":
        return int(value)
    if compare == "move_exact":
        return str(value).strip().lower()
    if compare == "move_set_exact":
        if not isinstance(value, Sequence) or isinstance(value, (str, bytes)):
            raise TypeError("move_set_exact expects a sequence of moves")
        return sorted(normalize_value("move_exact", item) for item in value)
    if compare == "status_exact":
        return str(value).strip().lower()
    if compare == "string_exact":
        return str(value).strip()
    raise ValueError(f"Unsupported compare mode: {compare}")


def compare_values(compare: str, expected: Any, actual: Any) -> Tuple[bool, Any, Any]:
    normalized_expected = normalize_value(compare, expected)
    normalized_actual = normalize_value(compare, actual)
    return normalized_expected == normalized_actual, normalized_expected, normalized_actual


def validate_report_schema(report: Dict[str, Any], expected_suite: str) -> List[str]:
    errors: List[str] = []

    if report.get("schema_version") != "1.0":
        errors.append("Report schema_version must be '1.0'")
    if report.get("suite") != expected_suite:
        errors.append(
            f"Report suite must be '{expected_suite}', got '{report.get('suite')}'"
        )
    if not isinstance(report.get("implementation"), str) or not report["implementation"].strip():
        errors.append("Report must define non-empty 'implementation'")
    cases = report.get("cases")
    if not isinstance(cases, list):
        errors.append("Report 'cases' must be a list")
        return errors

    seen_ids = set()
    for index, case in enumerate(cases, start=1):
        case_label = f"report case #{index}"
        if not isinstance(case, dict):
            errors.append(f"{case_label} must be an object")
            continue
        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id.strip():
            errors.append(f"{case_label} has invalid 'id'")
            continue
        if case_id in seen_ids:
            errors.append(f"Duplicate report case id: {case_id}")
        seen_ids.add(case_id)
        status = case.get("status")
        if status not in VALID_CASE_STATUSES:
            errors.append(
                f"Report case '{case_id}' has invalid status '{status}'"
            )

    return errors


def evaluate_report(
    contract_suite: Dict[str, Any],
    report: Dict[str, Any],
) -> Dict[str, Any]:
    suite_cases = {case["id"]: case for case in contract_suite["cases"]}
    report_cases = {case["id"]: case for case in report.get("cases", []) if isinstance(case, dict) and "id" in case}

    errors: List[str] = []
    passed = 0
    failed = 0
    skipped = 0

    for report_case_id in sorted(report_cases):
        if report_case_id not in suite_cases:
            errors.append(f"Report contains unknown case id '{report_case_id}'")

    for case_id, suite_case in suite_cases.items():
        report_case = report_cases.get(case_id)
        if report_case is None:
            errors.append(f"Missing report result for contract case '{case_id}'")
            failed += 1
            continue

        status = report_case.get("status")
        compare = suite_case["compare"]
        expected_value = suite_case["expect"]["value"]

        if status == "passed":
            if "normalized_actual" not in report_case:
                errors.append(
                    f"Passed report case '{case_id}' must include 'normalized_actual'"
                )
                failed += 1
                continue
            try:
                matches, normalized_expected, normalized_actual = compare_values(
                    compare,
                    expected_value,
                    report_case["normalized_actual"],
                )
            except Exception as exc:
                errors.append(f"Case '{case_id}' normalization failed: {exc}")
                failed += 1
                continue
            if not matches:
                errors.append(
                    f"Case '{case_id}' expected {normalized_expected!r} but got {normalized_actual!r}"
                )
                failed += 1
                continue
            passed += 1
        elif status == "skipped":
            skipped += 1
            if suite_case["required"]:
                errors.append(f"Required case '{case_id}' was skipped")
                failed += 1
        elif status == "failed":
            failed += 1
            message = report_case.get("error") or "adapter reported failure"
            if suite_case["required"]:
                errors.append(f"Required case '{case_id}' failed: {message}")
        else:
            failed += 1
            errors.append(f"Case '{case_id}' has invalid status '{status}'")

    return {
        "errors": errors,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": len(suite_cases),
    }


def docker_image_exists(image: str) -> bool:
    result = subprocess.run(
        ["docker", "image", "inspect", image],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def repo_to_container_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        relative = resolved.relative_to(REPO_ROOT)
    except ValueError as exc:
        raise ValueError(f"Path must be inside repository root: {resolved}") from exc
    return str(CONTAINER_REPO_ROOT / relative)


def run_contract_command(
    image: str,
    command: str,
    suite_path: Path,
) -> Tuple[int, str, str, str | None]:
    with tempfile.TemporaryDirectory() as tmp_dir:
        temp_root = Path(tmp_dir)
        report_path = temp_root / "unit-report.json"
        suite_in_container = repo_to_container_path(suite_path)
        report_in_container = "/work/unit-report.json"
        shell_command = (
            f"{command} --suite {shlex.quote(suite_in_container)} "
            f"--report {shlex.quote(report_in_container)}"
        )
        docker_args = [
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "-v",
            f"{REPO_ROOT}:/repo:ro",
            "-v",
            f"{temp_root}:/work",
            image,
        ]

        for shell in ("sh", "bash"):
            result = subprocess.run(
                docker_args + [shell, "-c", f"cd /app && {shell_command}"],
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode == 0 or "executable file not found in $PATH" not in (result.stderr or "").lower():
                report_text = None
                if report_path.exists():
                    report_text = report_path.read_text(encoding="utf-8")
                return result.returncode, result.stdout, result.stderr, report_text

        return result.returncode, result.stdout, result.stderr, None


def run_for_implementation(
    impl_path: Path,
    suite_path: Path,
    protocol_suite_path: Path,
    docker_image: str | None,
    require_contract: bool,
) -> int:
    metadata = get_metadata(str(impl_path))
    suite = load_json(suite_path)
    protocol_suite = load_json(protocol_suite_path)

    suite_errors = validate_contract_suite(suite)
    suite_errors.extend(lint_feature_vocabulary(suite, protocol_suite))
    if suite_errors:
        print("Contract suite validation failed:")
        for error in suite_errors:
            print(f"- {error}")
        return 1

    contract_command = metadata.get("test_contract", "")
    impl_name = impl_path.name
    image = docker_image or f"chess-{impl_name}"

    if not contract_command:
        message = (
            f"SKIPPED: {impl_name} does not declare org.chess.test_contract"
        )
        print(message)
        return 1 if require_contract else 0

    if not docker_image_exists(image):
        print(
            f"ERROR: Docker image '{image}' not found. Run: make image DIR={impl_name}",
            file=sys.stderr,
        )
        return 1

    print(f"Running unit contract suite for {impl_name} using image '{image}'")
    print(f"Contract command: {contract_command}")

    returncode, stdout, stderr, report_text = run_contract_command(
        image,
        contract_command,
        suite_path,
    )
    if stdout.strip():
        print(stdout.strip())
    if returncode != 0:
        print(f"ERROR: Contract adapter exited with status {returncode}")
        if stderr.strip():
            print(stderr.strip())
        return 1

    if report_text is None:
        print("ERROR: Contract adapter did not write /work/unit-report.json")
        if stderr.strip():
            print(stderr.strip())
        return 1

    try:
        report = json.loads(report_text)
    except Exception as exc:
        print(f"ERROR: Failed to load contract report: {exc}")
        return 1

    report_errors = validate_report_schema(report, suite["suite"])
    evaluation = evaluate_report(suite, report)
    report_errors.extend(evaluation["errors"])

    print(
        "Summary: "
        f"{evaluation['passed']}/{evaluation['total']} passed, "
        f"{evaluation['failed']} failed, "
        f"{evaluation['skipped']} skipped"
    )

    if report_errors:
        for error in report_errors:
            print(f"- {error}")
        return 1

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run shared unit-contract suite in Docker")
    parser.add_argument("--impl", required=True, help="Implementation name or path")
    parser.add_argument(
        "--suite",
        default=str(DEFAULT_SUITE),
        help="Path to contract suite JSON",
    )
    parser.add_argument(
        "--protocol-suite",
        default=str(DEFAULT_PROTOCOL_SUITE),
        help="Path to protocol suite JSON used for feature-vocabulary linting",
    )
    parser.add_argument(
        "--docker-image",
        help="Docker image name (defaults to chess-<impl>)",
    )
    parser.add_argument(
        "--require-contract",
        action="store_true",
        help="Fail when org.chess.test_contract is missing",
    )
    args = parser.parse_args()

    try:
        impl_path = resolve_impl_path(args.impl)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    suite_path = Path(args.suite).resolve()
    protocol_suite_path = Path(args.protocol_suite).resolve()

    return run_for_implementation(
        impl_path=impl_path,
        suite_path=suite_path,
        protocol_suite_path=protocol_suite_path,
        docker_image=args.docker_image,
        require_contract=args.require_contract,
    )


if __name__ == "__main__":
    raise SystemExit(main())
