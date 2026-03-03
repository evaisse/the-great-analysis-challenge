#!/usr/bin/env python3
"""
Simple static analysis for Python chess engine.
"""

import subprocess
import sys


def run_analysis():
    """Run static analysis tools."""
    print("🔍 Running Python static analysis...")
    print("=" * 50)

    tools = [
        (
            "mypy",
            [
                "python3",
                "-m",
                "mypy",
                ".",
                "--ignore-missing-imports",
                "--no-strict-optional",
                "--disable-error-code=no-untyped-def",
                "--disable-error-code=no-any-return",
                "--disable-error-code=call-overload",
                "--disable-error-code=unreachable",
                "--disable-error-code=misc",
                "--disable-error-code=has-type",
                "--disable-error-code=return-value",
            ],
        ),
        (
            "flake8",
            [
                "python3",
                "-m",
                "flake8",
                ".",
                "--max-line-length=110",
                "--max-complexity=25",
                "--extend-ignore=E128,E129,E131,E203,E231,E241,E302,E303,E304,E305,E501,E701,W291,W292,W293,W391,W503,W504,F541",
            ],
        ),
        ("black", ["python3", "-m", "black", "--check", "--diff", "."]),
        (
            "bandit",
            ["python3", "-m", "bandit", "-r", ".", "-f", "txt", "--skip", "B404,B603,B607"],
        ),
    ]

    all_passed = True

    for name, cmd in tools:
        print(f"\n📝 Running {name}...")
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)  # nosec B603
            if result.returncode == 0:
                print(f"✅ {name}: PASSED")
                if result.stdout.strip():
                    print(result.stdout[:500])
            else:
                print(f"❌ {name}: ISSUES FOUND")
                if result.stdout.strip():
                    print(result.stdout[:1000])
                if result.stderr.strip():
                    print("STDERR:", result.stderr[:500])
                all_passed = False
        except subprocess.TimeoutExpired:
            print(f"⏰ {name}: TIMEOUT")
            all_passed = False
        except FileNotFoundError:
            print(f"❓ {name}: Tool not installed")
        except Exception as e:
            print(f"❌ {name}: ERROR - {e}")
            all_passed = False

    print(f"\n{'✅ All checks passed!' if all_passed else '❌ Some issues found'}")
    print("📊 Analysis complete!")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(run_analysis())
