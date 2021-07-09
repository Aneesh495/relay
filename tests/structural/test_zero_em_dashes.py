#!/usr/bin/env python3
"""
RELAY INDUSTRIAL SCADA PLATFORM
Structural Verification: Strict Zero Em Dash Enforcement
File: tests/structural/test_zero_em_dashes.py

Scans all source code, headers, comments, documentation, and configuration
files across the entire repository to ensure zero em dashes are present.
"""

import os
import sys

EXCLUDE_DIRS = {".git", ".system_generated", "bin", "__pycache__"}
CHECK_EXTENSIONS = {
    ".bas", ".c", ".h", ".py", ".md", ".txt", ".sh", ".json", ".yaml", ".yml",
    "Makefile", "CMakeLists.txt", "LICENSE", ".gitignore"
}

def scan_repository(root_dir: str) -> tuple[int, list[str]]:
    files_scanned = 0
    violations = []
    
    # Target forbidden characters: unicode em dash (U+2014), HTML mdash
    forbidden_sequences = [
        ("\u2014", "Unicode Em Dash (U+2014)"),
        ("&mdash;", "HTML Entity &mdash;"),
    ]

    for root, dirs, files in os.walk(root_dir):
        # Filter out excluded directories
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        
        for fname in files:
            ext = os.path.splitext(fname)[1]
            if ext not in CHECK_EXTENSIONS and fname not in CHECK_EXTENSIONS:
                continue
            
            fpath = os.path.join(root, fname)
            relpath = os.path.relpath(fpath, root_dir)
            
            # Avoid self-matching test patterns
            if fname == "test_zero_em_dashes.py":
                continue
            
            files_scanned += 1
            try:
                with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                    for line_no, line in enumerate(f, start=1):
                        for seq, desc in forbidden_sequences:
                            if seq in line:
                                violations.append(f"{relpath}:{line_no} contains {desc}: {line.strip()[:80]}")
            except Exception as e:
                violations.append(f"{relpath}: Error reading file: {e}")

    return files_scanned, violations

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    files_scanned, violations = scan_repository(root_dir)
    
    print("=" * 80)
    print(" STRUCTURAL VERIFICATION: STRICT ZERO EM DASH AUDIT")
    print("=" * 80)
    print(f" Total Repository Files Scanned: {files_scanned}")
    
    if violations:
        print(f"\n [FAIL] Found {len(violations)} forbidden em dash occurrences:")
        for v in violations:
            print(f"   - {v}")
        print("=" * 80)
        sys.exit(1)
    else:
        print(f" [PASS] Repository is 100% clean: Exactly 0 em dashes detected across {files_scanned} files.")
        print("=" * 80)
        sys.exit(0)

if __name__ == "__main__":
    main()
