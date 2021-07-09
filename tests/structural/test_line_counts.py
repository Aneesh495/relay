#!/usr/bin/env python3
"""
RELAY INDUSTRIAL SCADA PLATFORM
Structural Verification: Codebase Line Count & Metric Analysis
File: tests/structural/test_line_counts.py

Computes physical lines of code (SLOC), comments, and documentation
across all programming languages in the project.
"""

import os
import sys

EXCLUDE_DIRS = {".git", ".system_generated", "bin", "__pycache__"}

def analyze_file(filepath: str, ext: str) -> tuple[int, int, int]:
    total_lines = 0
    comment_lines = 0
    blank_lines = 0

    comment_markers = {
        ".bas": ("'", "REM"),
        ".c": ("//", "/*", "*"),
        ".h": ("//", "/*", "*"),
        ".py": ("#", '"""', "'''"),
        ".md": ("<!--",),
    }

    markers = comment_markers.get(ext, ("#",))

    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                total_lines += 1
                stripped = line.strip()
                if not stripped:
                    blank_lines += 1
                elif any(stripped.startswith(m) for m in markers):
                    comment_lines += 1
    except Exception:
        pass

    return total_lines, comment_lines, blank_lines

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    stats = {
        "BASIC (.bas)": {"files": 0, "total": 0, "comments": 0, "blank": 0},
        "C Runtime (.c, .h)": {"files": 0, "total": 0, "comments": 0, "blank": 0},
        "Python (.py)": {"files": 0, "total": 0, "comments": 0, "blank": 0},
        "Documentation (.md)": {"files": 0, "total": 0, "comments": 0, "blank": 0},
    }

    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for fname in files:
            ext = os.path.splitext(fname)[1].lower()
            category = None
            if ext == ".bas":
                category = "BASIC (.bas)"
            elif ext in (".c", ".h"):
                category = "C Runtime (.c, .h)"
            elif ext == ".py":
                category = "Python (.py)"
            elif ext == ".md":
                category = "Documentation (.md)"
            
            if category:
                fpath = os.path.join(root, fname)
                tot, com, blk = analyze_file(fpath, ext)
                stats[category]["files"] += 1
                stats[category]["total"] += tot
                stats[category]["comments"] += com
                stats[category]["blank"] += blk

    print("=" * 80)
    print(" RELAY CODEBASE SCALE & COMMENT-TO-CODE ANALYSIS")
    print("=" * 80)
    print(f" {'LANGUAGE / LAYER':<24} {'FILES':<8} {'CODE':<10} {'COMMENTS':<10} {'BLANK':<8} {'TOTAL':<10}")
    print("-" * 80)

    grand_files = 0
    grand_code = 0
    grand_comments = 0
    grand_blank = 0
    grand_total = 0

    for cat, data in stats.items():
        code_lines = data["total"] - data["comments"] - data["blank"]
        grand_files += data["files"]
        grand_code += code_lines
        grand_comments += data["comments"]
        grand_blank += data["blank"]
        grand_total += data["total"]

        print(f" {cat:<24} {data['files']:<8} {code_lines:<10} {data['comments']:<10} {data['blank']:<8} {data['total']:<10}")

    print("-" * 80)
    print(f" {'AGGREGATE TOTALS':<24} {grand_files:<8} {grand_code:<10} {grand_comments:<10} {grand_blank:<8} {grand_total:<10}")
    print("=" * 80)
    
    if grand_code > 0:
        ratio = (grand_comments / grand_code) * 100.0
        print(f" Overall Comment-to-Code Ratio: {ratio:.1f}%")
    print("=" * 80)

if __name__ == "__main__":
    main()
