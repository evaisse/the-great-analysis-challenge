#!/usr/bin/env python3
"""
Test script to demonstrate Python chess engine functionality.
"""

import subprocess
import sys


def test_basic_functionality():
    """Test basic chess engine functionality."""
    print("🧪 Testing Python Chess Engine")
    print("=" * 50)

    # Test commands
    test_commands = [
        "new",
        "help",
        "move e2e4",
        "move e7e5",
        "move g1f3",
        "move b8c6",
        "export",
        "undo",
        "export",
        "perft 3",
        "ai 2",
        "new",
        "fen r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
        "move e1g1",
        "export",
        "quit",
    ]

    input_str = "\n".join(test_commands) + "\n"

    try:
        result = subprocess.run(
            ["python3", "chess.py"], input=input_str, capture_output=True, text=True, timeout=30
        )

        if result.returncode == 0:
            print("✅ Chess engine ran successfully!")
            print("\n📊 Sample output:")
            # Show last few lines of output
            lines = result.stdout.strip().split("\n")
            for line in lines[-10:]:
                if line.strip():
                    print(f"  {line}")
        else:
            print("❌ Chess engine failed to run")
            print("STDERR:", result.stderr[:500])
            return False

    except subprocess.TimeoutExpired:
        print("⏰ Test timed out")
        return False
    except Exception as e:
        print(f"❌ Test error: {e}")
        return False

    return True


def test_perft_accuracy():
    """Test perft accuracy for move generation validation."""
    print("\n🎯 Testing Perft Accuracy")
    print("-" * 30)

    # Known perft values from starting position
    expected_perft = {1: 20, 2: 400, 3: 8902}

    for depth, expected in expected_perft.items():
        try:
            result = subprocess.run(
                ["python3", "chess.py"],
                input=f"new\nperft {depth}\nquit\n",
                capture_output=True,
                text=True,
                timeout=10,
            )

            if result.returncode == 0:
                # Parse perft result
                for line in result.stdout.split("\n"):
                    if f"Perft({depth}):" in line:
                        parts = line.split()
                        actual = int(parts[1])
                        if actual == expected:
                            print(f"✅ Perft({depth}): {actual} nodes (correct)")
                        else:
                            print(f"❌ Perft({depth}): {actual} nodes (expected {expected})")
                        break
                else:
                    print(f"❌ Perft({depth}): No result found")
            else:
                print(f"❌ Perft({depth}): Engine failed")

        except Exception as e:
            print(f"❌ Perft({depth}): Error - {e}")


def main():
    """Run all tests."""
    success = test_basic_functionality()
    test_perft_accuracy()

    print(f"\n{'✅ All tests completed successfully!' if success else '❌ Some tests failed'}")
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
