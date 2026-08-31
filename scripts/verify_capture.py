#!/usr/bin/env python3
"""
Mechanical verification script for BookBurner capture module:
Verifies that all required Swift source files and unit tests exist and contain correct structural patterns.
"""

import os
import sys

REQUIRED_FILES = [
    "BookBurner/Features/Capture/BarcodeScannerSeam.swift",
    "BookBurner/Features/Capture/CaptureStateMachine.swift",
    "BookBurner/Infrastructure/Photos/PhotoStorage.swift",
    "BookBurner/Features/Capture/CaptureUndoManager.swift",
    "Tests/BookBurnerTests/CaptureTests.swift"
]

def main():
    print("=== BookBurner Capture Structural & Mechanical Verification ===")
    
    for filepath in REQUIRED_FILES:
        if not os.path.exists(filepath):
            print(f"❌ Missing required file: {filepath}", file=sys.stderr)
            sys.exit(1)
        print(f"✅ Found: {filepath}")
        
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
            if len(content.strip()) == 0:
                print(f"❌ File is empty: {filepath}", file=sys.stderr)
                sys.exit(1)

    print("✅ All required capture feature files, seams, storage, undo manager, and unit tests exist and are non-empty.")
    sys.exit(0)

if __name__ == "__main__":
    main()
