#!/usr/bin/env python3
"""Verify the release web bundle contains the compile-time Gemini API key."""
import os
import sys
from pathlib import Path


def main() -> int:
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if len(key) < 8:
        print("::error::GEMINI_API_KEY missing or too short for bundle verification")
        return 1

    js_path = Path("build/web/main.dart.js")
    if not js_path.is_file():
        print(f"::error::{js_path} not found — run flutter build web first")
        return 1

    bundle = js_path.read_text(encoding="utf-8", errors="ignore")

    # ApiSecrets injects the full key as a Dart const → appears in minified JS.
    if key not in bundle:
        prefix = key[:12]
        if prefix not in bundle:
            print(
                "::error::GEMINI_API_KEY not found in main.dart.js. "
                "ApiSecrets may not be linked into the release build."
            )
            return 1
        print("Bundle contains API key prefix (minified/split string).")

    print(f"Bundle verification passed ({js_path.stat().st_size} bytes).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
