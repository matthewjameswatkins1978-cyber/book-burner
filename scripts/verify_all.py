#!/usr/bin/env python3
import subprocess
import sys
import os

def main():
    print("==================================================")
    print(" Book Burner 0.1 Capture Edition - Comprehensive Verification Runner")
    print("==================================================")

    scripts = [
        ("Core Domain & Algorithms", "scripts/verify_core.py"),
        ("Metadata Subsystem & Fallback", "scripts/verify_metadata.py"),
        ("Capture Workflow & State Machine", "scripts/verify_capture.py"),
        ("Export & Archiving Engine", "scripts/verify_export.py"),
        ("UI & Accessibility State", "scripts/verify_ui.py")
    ]

    results = []
    overall_success = True

    for name, script_path in scripts:
        print(f"\n[RUNNING] {name} ({script_path})...")
        if not os.path.exists(script_path):
            print(f"  [ERROR] Script not found: {script_path}")
            results.append((name, script_path, False, "Script not found"))
            overall_success = False
            continue

        try:
            process = subprocess.run(
                [sys.executable, script_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            if process.returncode == 0:
                print(f"  [PASS] {name}")
                results.append((name, script_path, True, process.stdout))
            else:
                print(f"  [FAIL] {name} (exit code {process.returncode})")
                print("--- STDOUT ---")
                print(process.stdout)
                print("--- STDERR ---")
                print(process.stderr)
                results.append((name, script_path, False, process.stderr or process.stdout))
                overall_success = False
        except Exception as e:
            print(f"  [ERROR] Exception running {script_path}: {e}")
            results.append((name, script_path, False, str(e)))
            overall_success = False

    print("\n==================================================")
    print(" VERIFICATION SUMMARY")
    print("==================================================")
    for name, script_path, success, details in results:
        status = "PASS" if success else "FAIL"
        print(f" - [{status}] {name} ({script_path})")
    print("==================================================")

    if overall_success:
        print("=== ALL BOOK BURNER VERIFICATION CHECKS PASSED ===")
        sys.exit(0)
    else:
        print("=== SOME VERIFICATION CHECKS FAILED ===")
        sys.exit(1)

if __name__ == "__main__":
    main()
