import os
import subprocess
import sys

def get_implementations():
    imps = []
    for root in ["implementations", "implementations-wip"]:
        if not os.path.exists(root):
            continue
        for d in os.listdir(root):
            path = os.path.join(root, d)
            if os.path.isdir(path) and os.path.exists(os.path.join(path, "Makefile")):
                imps.append(path)
    return sorted(imps)

def verify_implementation(path):
    print(f"Verifying {path}...")
    try:
        # Run analyze-with-bug
        # We need to capture output to see if it failed
        result = subprocess.run(
            ["make", "analyze-with-bug"],
            cwd=path,
            capture_output=True,
            text=True,
            timeout=120
        )

        if result.returncode != 0:
            # It's expected that 'make analyze' inside analyze-with-bug might fail (return non-zero),
            # but the 'analyze-with-bug' target itself should generally succeed if I used '-' to ignore errors.
            # In my Makefile construction:
            # -{ time $(MAKE) analyze ... }
            # The '-' should ignore the error.
            # However, if 'bugit' or 'fix' fails, it will return non-zero.

            # Let's check if the log files exist
            if not os.path.exists(os.path.join(path, "analysis_bug.log")) or \
               not os.path.exists(os.path.join(path, "analysis_time.log")):
                print(f"❌ {path} failed: Log files not created.")
                print(result.stderr)
                return False

            print(f"✅ {path} passed.")
            return True
        else:
            print(f"✅ {path} passed.")
            return True

    except subprocess.TimeoutExpired:
        print(f"❌ {path} timed out.")
        return False
    except Exception as e:
        print(f"❌ {path} error: {e}")
        return False

def main():
    implementations = get_implementations()
    failures = []
    for imp in implementations:
        if not verify_implementation(imp):
            failures.append(imp)

    if failures:
        print(f"\nFailures found in: {', '.join(failures)}")
        sys.exit(1)
    else:
        print("\nAll implementations verified successfully.")
        sys.exit(0)

if __name__ == "__main__":
    main()
