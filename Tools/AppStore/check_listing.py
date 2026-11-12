#!/usr/bin/env python3
"""Checks the App Store text lengths in docs/appstore/listing.md."""
import os
import re
import sys

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "appstore", "listing.md")
text = open(PATH, encoding="utf-8").read()
ok = True
for label, limit, block in re.findall(r"\*\*([^*]+)\*\* \((?:max\.? )(\d+)[^)]*\)\n```\n(.*?)\n```", text, re.S):
    length = len(block)
    if label.startswith(("Trefwoorden", "Keywords")) and ", " in block:
        print(f"{label}: no spaces after commas")
        ok = False
    status = "ok" if length <= int(limit) else "TOO LONG"
    ok &= length <= int(limit)
    print(f"{status:8} {length:5}/{limit:<5} {label}")
sys.exit(0 if ok else 1)
