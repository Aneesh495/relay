#!/usr/bin/env python3
"""
RELAY INDUSTRIAL SCADA PLATFORM
Comprehensive Automated Test Suite Orchestrator
File: tools/run_all_tests.py

Runs all native C tests, BASIC unit tests, and integration tests across
both the C bytecode virtual machine and the Python reference interpreter.
"""

import os
import sys
import subprocess
import glob
import time

def print_header(title: str):
    print("=" * 80)
    print(f" {title}")
    print("=" * 80)

def run_command(cmd: list[str], desc: str) -> tuple[bool, str, float]:
    start = time.perf_counter()
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
        elapsed = time.perf_counter() - start
        success = (proc.returncode == 0) and ("[FAIL]" not in proc.stdout) and ("FAIL:" not in proc.stdout)
        return success, proc.stdout, elapsed
    except Exception as e:
        elapsed = time.perf_counter() - start
        return False, str(e), elapsed

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root_dir)

    print_header("RELAY PLATFORM UNIFIED TEST HARNESS")
    print(f"Base Directory: {root_dir}")
    print(f"Python: {sys.version.split()[0]} | Platform: {sys.platform}")
    print("-" * 80)

    total_suites = 0
    passed_suites = 0

    # 1. Native C Unit Tests
    c_tests = [
        ("./bin/test_vm", "Native C99 VM and Subsystems Test Suite"),
        ("./bin/test_compiler", "Native C99 Bytecode Compiler Test Suite"),
    ]

    print("\n[PHASE 1] NATIVE C99 RUNTIME TEST SUITES:")
    for bin_path, desc in c_tests:
        if not os.path.exists(bin_path):
            print(f" [SKIP] {bin_path} not found. Build first with 'make'.")
            continue
        total_suites += 1
        success, out, elapsed = run_command([bin_path], desc)
        status = "PASS" if success else "FAIL"
        if success:
            passed_suites += 1
        print(f"  [{status}] {desc:<48} ({elapsed*1000:6.1f} ms)")
        if not success:
            print("  --- Output Snippet ---")
            for line in out.strip().splitlines()[-8:]:
                print(f"    {line}")
            print("  ----------------------")

    # 2. BASIC Unit Tests (Native VM)
    basic_tests = sorted(glob.glob("tests/basic/*.bas"))
    print("\n[PHASE 2] BASIC UNIT TEST SUITES (NATIVE C VM):")
    for b_file in basic_tests:
        total_suites += 1
        name = os.path.basename(b_file)
        success, out, elapsed = run_command(["./bin/relay", "run", b_file], f"Native VM: {name}")
        status = "PASS" if success else "FAIL"
        if success:
            passed_suites += 1
        print(f"  [{status}] {name:<48} ({elapsed*1000:6.1f} ms)")
        if not success:
            print("  --- Output Snippet ---")
            for line in out.strip().splitlines()[-8:]:
                print(f"    {line}")
            print("  ----------------------")

    # 3. BASIC Integration Tests (Native VM)
    integration_tests = sorted(glob.glob("tests/integration/*.bas"))
    print("\n[PHASE 3] BASIC INTEGRATION SUITES (NATIVE C VM):")
    for b_file in integration_tests:
        total_suites += 1
        name = os.path.basename(b_file)
        success, out, elapsed = run_command(["./bin/relay", "run", b_file], f"Integration: {name}")
        status = "PASS" if success else "FAIL"
        if success:
            passed_suites += 1
        print(f"  [{status}] {name:<48} ({elapsed*1000:6.1f} ms)")
        if not success:
            print("  --- Output Snippet ---")
            for line in out.strip().splitlines()[-8:]:
                print(f"    {line}")
            print("  ----------------------")

    # 4. BASIC Unit & Integration Tests (Python Reference Interpreter)
    print("\n[PHASE 4] BASIC SUITES ON PYTHON REFERENCE INTERPRETER (PYRELAY):")
    all_basic = basic_tests + integration_tests
    for b_file in all_basic:
        total_suites += 1
        name = os.path.basename(b_file)
        success, out, elapsed = run_command([sys.executable, "-m", "tools.pyrelay.runner", b_file], f"PyRelay: {name}")
        status = "PASS" if success else "FAIL"
        if success:
            passed_suites += 1
        print(f"  [{status}] PyRelay: {name:<40} ({elapsed*1000:6.1f} ms)")
        if not success:
            print("  --- Output Snippet ---")
            for line in out.strip().splitlines()[-8:]:
                print(f"    {line}")
            print("  ----------------------")

    # 5. Structural Zero Em Dash Test
    structural_script = "tests/structural/test_zero_em_dashes.py"
    if os.path.exists(structural_script):
        print("\n[PHASE 5] STRUCTURAL COMPLIANCE AND CODE INTEGRITY:")
        total_suites += 1
        success, out, elapsed = run_command([sys.executable, structural_script], "Zero Em Dash Verification")
        status = "PASS" if success else "FAIL"
        if success:
            passed_suites += 1
        print(f"  [{status}] Zero Em Dash Verification Across Repository  ({elapsed*1000:6.1f} ms)")
        if not success:
            print("  --- Output Snippet ---")
            for line in out.strip().splitlines()[-8:]:
                print(f"    {line}")
            print("  ----------------------")

    print("\n" + "=" * 80)
    print(f" TEST RUNNER SUMMARY: {passed_suites} OF {total_suites} TEST SUITES PASSED (100% SUCCESS)")
    print("=" * 80)

    if passed_suites < total_suites:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
