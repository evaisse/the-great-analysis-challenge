#!/usr/bin/env python3
"""Run concurrency safety checks across implementations."""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple

# Ensure repository root is importable
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

TEST_DIR = REPO_ROOT / "test"
if str(TEST_DIR) not in sys.path:
    sys.path.insert(0, str(TEST_DIR))

from chess_metadata import get_metadata
from test_harness import ChessEngineTester

DEFAULT_PROFILE_SPECS = {
    "quick": {
        "command": "concurrency quick",
        "timeout_seconds": 120,
        "required_fields": [
            "profile", "seed", "workers", "runs", "checksums",
            "deterministic", "invariant_errors", "deadlocks", "timeouts",
            "elapsed_ms", "ops_total",
        ],
        "expected_zero_fields": ["invariant_errors", "deadlocks", "timeouts"],
        "require_deterministic": True,
    },
    "full": {
        "command": "concurrency full",
        "timeout_seconds": 300,
        "required_fields": [
            "profile", "seed", "workers", "runs", "checksums",
            "deterministic", "invariant_errors", "deadlocks", "timeouts",
            "elapsed_ms", "ops_total",
        ],
        "expected_zero_fields": ["invariant_errors", "deadlocks", "timeouts"],
        "require_deterministic": True,
    },
}


def discover_implementations(base_dir: Path) -> List[Path]:
    return [
        p for p in sorted(base_dir.iterdir())
        if p.is_dir() and (p / "Dockerfile").exists()
    ]


def build_image(impl_name: str) -> bool:
    cmd = ["make", "build", f"DIR={impl_name}"]
    print(f"🔧 Building Docker image for {impl_name}...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        return False
    return True


def extract_concurrency_payload(output: str) -> Tuple[bool, Dict, str]:
    for line in output.splitlines():
        if line.strip().upper().startswith("CONCURRENCY:"):
            payload_raw = line.split(":", 1)[1].strip()
            try:
                payload = json.loads(payload_raw)
                return True, payload, ""
            except json.JSONDecodeError as exc:
                return False, {}, f"Invalid JSON payload: {exc}"
    return False, {}, "Missing CONCURRENCY: payload"


def load_profile_specs(path: Path) -> Dict[str, Dict]:
    if not path.exists():
        return DEFAULT_PROFILE_SPECS
    try:
        with path.open("r", encoding="utf-8") as handle:
            raw = json.load(handle)
        profiles = raw.get("profiles")
        if isinstance(profiles, dict):
            return profiles
    except Exception:
        pass
    return DEFAULT_PROFILE_SPECS


def validate_payload(payload: Dict, profile_spec: Dict) -> List[str]:
    issues = []

    if profile_spec.get("require_deterministic", True) and payload.get("deterministic") is not True:
        issues.append("deterministic must be true")

    zero_fields = profile_spec.get("expected_zero_fields", [])
    for key in zero_fields:
        if payload.get(key, 0) != 0:
            issues.append(f"{key} must be 0 (got {payload.get(key)})")

    required_fields = profile_spec.get("required_fields", [])
    for field in required_fields:
        if field not in payload:
            issues.append(f"missing field: {field}")

    return issues


def run_for_implementation(impl_path: Path, profile: str, profile_spec: Dict, docker_image: str) -> Dict:
    metadata = get_metadata(str(impl_path))
    tester = ChessEngineTester(str(impl_path), metadata, docker_image=docker_image)

    result = {
        "implementation": impl_path.name,
        "docker_image": docker_image,
        "profile": profile,
        "status": "failed",
        "issues": [],
        "payload": None,
    }

    if not tester.start():
        result["issues"].append("engine failed to start")
        result["issues"].extend(tester.results.get("errors", []))
        return result

    try:
        command = profile_spec.get("command", f"concurrency {profile}")
        timeout_seconds = int(profile_spec.get("timeout_seconds", 120 if profile == "quick" else 300))
        output = tester.send_command(command, timeout=timeout_seconds)
        ok, payload, parse_error = extract_concurrency_payload(output)
        if not ok:
            result["issues"].append(parse_error)
            return result

        result["payload"] = payload
        payload_issues = validate_payload(payload, profile_spec)
        if payload_issues:
            result["issues"].extend(payload_issues)
            return result

        result["status"] = "passed"
        return result
    finally:
        tester.stop()


def main() -> int:
    parser = argparse.ArgumentParser(description="Concurrency safety harness")
    parser.add_argument("--impl", metavar="PATH", help="Single implementation path")
    parser.add_argument("--dir", default="implementations", metavar="DIR", help="Implementations directory")
    parser.add_argument("--profile", choices=["quick", "full"], default="quick")
    parser.add_argument("--docker-image", metavar="IMAGE", help="Docker image for single --impl mode")
    parser.add_argument("--skip-build", action="store_true", help="Skip make build")
    parser.add_argument(
        "--fixture",
        default="test/fixtures/concurrency/profiles.json",
        metavar="FILE",
        help="Concurrency profile fixture JSON",
    )
    parser.add_argument("--output", metavar="FILE", help="Write JSON report to file")

    args = parser.parse_args()
    profile_specs = load_profile_specs(Path(args.fixture))
    profile_spec = profile_specs.get(args.profile)
    if not profile_spec:
        print(f"Unknown profile '{args.profile}' in fixture {args.fixture}")
        return 1

    if args.impl:
        implementations = [Path(args.impl)]
    else:
        implementations = discover_implementations(Path(args.dir))

    if not implementations:
        print("No implementations found")
        return 1

    results = []

    for impl_path in implementations:
        impl_name = impl_path.name
        image_name = args.docker_image if args.impl and args.docker_image else f"chess-{impl_name}"

        if not args.skip_build:
            if not build_image(impl_name):
                results.append({
                    "implementation": impl_name,
                    "docker_image": image_name,
                    "profile": args.profile,
                    "status": "failed",
                    "issues": ["docker build failed"],
                    "payload": None,
                })
                continue

        print(f"🧪 Running concurrency {args.profile} for {impl_name}...")
        results.append(run_for_implementation(impl_path, args.profile, profile_spec, image_name))

    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            json.dump(results, handle, indent=2)

    failed = [r for r in results if r["status"] != "passed"]

    print("\n=== Concurrency Harness Summary ===")
    for entry in results:
        status_symbol = "✅" if entry["status"] == "passed" else "❌"
        print(f"{status_symbol} {entry['implementation']} ({entry['profile']})")
        if entry["issues"]:
            for issue in entry["issues"]:
                print(f"   - {issue}")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
