#!/usr/bin/env python3
"""Prints the crash reports TestFlight testers shared, newest first (only the crash itself:
exception, reason and the crashed thread; no tester details).

Needs ASC_KEY_ID, ASC_ISSUER_ID, BUNDLE_ID and ~/private_keys/AuthKey.p8 (pip install pyjwt cryptography).
"""
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"


def token():
    key = open(os.path.expanduser("~/private_keys/AuthKey.p8")).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def get(path, auth):
    request = urllib.request.Request(f"{API}{path}", headers={"Authorization": f"Bearer {auth}"})
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read())


def crash_part(text):
    """Keeps the lines that explain the crash."""
    keep, in_thread = [], False
    for line in text.splitlines():
        if re.match(r"^(Exception Type|Exception Reason|Exception Codes|Termination Reason|Triggered by Thread|"
                    r"Crashed Thread|OS Version|Version|Application Specific Information)", line):
            keep.append(line)
        if re.match(r"^Thread \d+ Crashed", line) or line.startswith("Last Exception Backtrace"):
            in_thread = True
            keep.append(line)
            continue
        if in_thread:
            if not line.strip():
                in_thread = False
                keep.append("")
            else:
                keep.append(line)
    return "\n".join(keep[:120]) if keep else text[:4000]


def main():
    auth = token()
    bundle = urllib.parse.quote(os.environ["BUNDLE_ID"])
    apps = get(f"/apps?filter[bundleId]={bundle}", auth)["data"]
    if not apps:
        print("App not found in App Store Connect.")
        return
    app_id = apps[0]["id"]
    try:
        crashes = get(f"/apps/{app_id}/betaFeedbackCrashSubmissions?limit=5&sort=-createdDate", auth)["data"]
    except urllib.error.HTTPError as error:
        print(f"Crash submissions not available ({error.code}).")
        return
    print(f"{len(crashes)} shared crash report(s).")
    for crash in crashes:
        attributes = crash["attributes"]
        print(f"\n===== {attributes.get('createdDate')} | build {attributes.get('buildBundleId', '')} "
              f"| {attributes.get('deviceModel')} | iOS {attributes.get('osVersion')} =====")
        try:
            log = get(f"/betaFeedbackCrashSubmissions/{crash['id']}/crashLog", auth)["data"]["attributes"]
            print(crash_part(log.get("logText", "")))
        except urllib.error.HTTPError as error:
            print(f"(no crash log: {error.code})")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # diagnostics only
        print(f"Crash report lookup failed: {error}")
