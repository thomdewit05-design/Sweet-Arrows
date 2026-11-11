#!/usr/bin/env python3
"""Writes Tools/Localization/translations.py into the string catalogs."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from translations import LANGS, NL_EXTRA, T, TRACKING  # noqa: E402

RES = os.path.join(HERE, "..", "..", "SweetArrows", "Resources")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


path = os.path.join(RES, "Localizable.xcstrings")
catalog = json.load(open(path))
strings = catalog["strings"]
for key, value in NL_EXTRA.items():
    strings.setdefault(key, {}).setdefault("localizations", {})["nl"] = unit(value)
missing = []
for key, entry in strings.items():
    if "localizations" not in entry:
        continue
    row = T.get(key)
    if row is None:
        missing.append(key)
        continue
    for lang, value in zip(LANGS, row):
        entry["localizations"][lang] = unit(value if value is not None else key)
catalog["strings"] = dict(sorted(strings.items(), key=lambda kv: kv[0].lower()))
json.dump(catalog, open(path, "w"), indent=2, ensure_ascii=False)
open(path, "a").write("\n")

info_path = os.path.join(RES, "InfoPlist.xcstrings")
info = json.load(open(info_path))
for lang, value in zip(LANGS, TRACKING):
    info["strings"]["NSUserTrackingUsageDescription"]["localizations"][lang] = unit(value)
json.dump(info, open(info_path, "w"), indent=2, ensure_ascii=False)
open(info_path, "a").write("\n")

if missing:
    print("missing translations:", missing)
    sys.exit(1)
print(f"translated {len(T)} strings into {', '.join(LANGS)}")
