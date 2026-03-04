#!/usr/bin/env python3
"""Run chess engine protocol tests against a Docker image."""

from __future__ import annotations

import argparse
import select
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Ensure repository root is importable
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

TEST_DIR = REPO_ROOT / "test"
if str(TEST_DIR) not in sys.path:
    sys.path.insert(0, str(TEST_DIR))

SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

# Reuse suite loader and validation logic
from test_harness import TestSuite
from chess_metadata import get_metadata


class DockerChessEngineTester:
    """Interactive tester that drives a chess engine running inside Docker."""

    def __init__(self, image: str, run_command: str):
        self.image = image
        self.run_command = run_command
        self.process: Optional[subprocess.Popen[str]] = None
        self.results: Dict[str, List] = {
            "passed": [],
            "failed": [],
            "performance": {},
            "errors": [],
        }

    def start(self) -> bool:
        try:
            cmd = [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "-i",
                self.image,
                "sh",
                "-lc",
                f"cd /app && {self.run_command}",
            ]
            self.process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=0,
            )
            return True
        except Exception as exc:
            self.results["errors"].append(f"Failed to start Docker engine process: {exc}")
            return False

    def send_command(self, command: str, timeout: float = 10.0) -> str:
        if not self.process or not self.process.stdin or not self.process.stdout:
            return ""

        try:
            self.process.stdin.write(command + "\n")
            self.process.stdin.flush()

            output_lines: List[str] = []
            start_time = time.time()
            last_output_time: Optional[float] = None

            end_keywords = [
                "OK:",
                "ERROR:",
                "CHECKMATE:",
                "STALEMATE:",
                "FEN:",
                "AI:",
                "EVALUATION:",
                "HASH:",
                "REPETITION:",
                "DRAW:",
            ]

            while time.time() - start_time < timeout:
                if self.process.poll() is not None:
                    break

                ready, _, _ = select.select([self.process.stdout], [], [], 0.1)
                if ready:
                    line = self.process.stdout.readline()
                    if not line:
                        continue

                    stripped = line.strip()
                    output_lines.append(stripped)
                    last_output_time = time.time()

                    if any(keyword in stripped.upper() for keyword in end_keywords):
                        break

                # Break when output has settled and no explicit protocol keyword was seen.
                if output_lines and last_output_time and time.time() - last_output_time > 0.2:
                    break

            return "\n".join(output_lines)
        except Exception as exc:
            self.results["errors"].append(f"Command error: {exc}")
            return ""

    def stop(self) -> None:
        if not self.process:
            return

        try:
            if self.process.poll() is None:
                if self.process.stdin:
                    self.process.stdin.write("quit\n")
                    self.process.stdin.flush()
                time.sleep(0.2)
            if self.process.poll() is None:
                self.process.terminate()
            self.process.wait(timeout=2)
        except Exception:
            try:
                self.process.kill()
            except Exception:
                pass
        finally:
            self.process = None


def resolve_impl_path(impl: str) -> Path:
    candidate = Path(impl)
    if candidate.exists():
        return candidate.resolve()

    fallback = REPO_ROOT / "implementations" / impl
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


def run_suite(impl_path: Path, image: str, run_command: str) -> Tuple[int, int, List[str]]:
    suite = TestSuite(str(REPO_ROOT / "test" / "test_suite.json"))

    passed = 0
    failed = 0
    errors: List[str] = []

    for index, test_case in enumerate(suite.tests, start=1):
        tester = DockerChessEngineTester(image, run_command)
        if not tester.start():
            failed += 1
            errors.extend(tester.results.get("errors", []))
            print(f"[{index}/{len(suite.tests)}] ❌ {test_case['name']} (engine start failed)")
            continue

        success = suite.run_test(tester, test_case)
        if success:
            passed += 1
            print(f"[{index}/{len(suite.tests)}] ✅ {test_case['name']}")
        else:
            failed += 1
            print(f"[{index}/{len(suite.tests)}] ❌ {test_case['name']}")
            for failure in tester.results.get("failed", [])[-1:]:
                if isinstance(failure, dict):
                    err = failure.get("error")
                    out = failure.get("output")
                    if err:
                        errors.append(f"{test_case['name']}: {err}")
                    elif out:
                        errors.append(f"{test_case['name']}: unexpected output")

        errors.extend(tester.results.get("errors", []))
        tester.stop()

    return passed, failed, errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Run chess engine protocol tests in Docker")
    parser.add_argument("--impl", required=True, help="Implementation name or path")
    parser.add_argument("--image", help="Docker image name (defaults to chess-<impl>)")
    args = parser.parse_args()

    try:
        impl_path = resolve_impl_path(args.impl)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    impl_name = impl_path.name
    image = args.image or f"chess-{impl_name}"

    if not docker_image_exists(image):
        print(
            f"ERROR: Docker image '{image}' not found. Run: make image DIR={impl_name}",
            file=sys.stderr,
        )
        return 1

    metadata = get_metadata(str(impl_path))
    run_command = metadata.get("run", "")
    if not run_command:
        print(
            f"ERROR: Missing metadata command 'org.chess.run' for {impl_name}",
            file=sys.stderr,
        )
        return 1

    print(f"Running full chess engine suite for {impl_name} using image '{image}'")
    print(f"Engine command: {run_command}")

    passed, failed, errors = run_suite(impl_path, image, run_command)

    print("\n" + "=" * 60)
    print("CHESS ENGINE SUITE SUMMARY")
    print("=" * 60)
    print(f"Implementation: {impl_name}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")

    if errors:
        print("Errors:")
        for error in errors[:20]:
            print(f"- {error}")
        if len(errors) > 20:
            print(f"- ... and {len(errors) - 20} more")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
