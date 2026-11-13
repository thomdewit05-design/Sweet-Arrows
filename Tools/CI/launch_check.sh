#!/bin/bash
# Usage: launch_check.sh <old.app> <new.app>
# On the oldest and the newest iPhone simulator: install the old app and start it (it leaves its save
# data behind, like a phone that had an earlier build), install the new app over it and start it twice.
# Fails when the new app is not running 30 s after a start, and prints its crash report.
set -u
OLD_APP=$1
NEW_APP=$2
BUNDLE_ID=${BUNDLE_ID:-com.lucthomasdewit.sweetarrows.com}
STATUS=0

SIMS=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
ios = sorted((k for k in devices if "iOS" in k), key=lambda k: [int(p) for p in k.split("iOS-")[-1].split("-")])
picked = []
for runtime in ios:
    phones = [d for d in devices[runtime] if d["name"].startswith("iPhone")]
    if phones:
        picked.append((runtime.split(".")[-1], phones[0]["udid"]))
for runtime, udid in sorted(set([picked[0], picked[-1]])):
    print(runtime, udid)
')

running() { xcrun simctl spawn "$1" launchctl list | grep -q "UIKitApplication:$BUNDLE_ID"; }

start() {  # udid label
    xcrun simctl launch --console-pty --terminate-running-process "$1" "$BUNDLE_ID" > "$RUNNER_TEMP/$2.log" 2>&1 &
    sleep 30
    if running "$1"; then
        echo "$2: still running after 30 s"
    else
        echo "::error::$2: NOT running after 30 s (crashed or quit)"
        tail -n 40 "$RUNNER_TEMP/$2.log"
        STATUS=1
    fi
    xcrun simctl spawn "$1" log show --last 1m --style compact \
        --predicate 'process == "SweetArrows" AND (messageType == fault OR eventMessage CONTAINS[c] "exception" OR eventMessage CONTAINS[c] "fatal" OR eventMessage CONTAINS[c] "assert")' \
        | tail -n 30 || true
    xcrun simctl terminate "$1" "$BUNDLE_ID" 2>/dev/null || true
    sleep 3
}

while read -r RUNTIME UDID; do
    [ -n "$UDID" ] || continue
    echo "::group::$RUNTIME ($UDID)"
    xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" > /dev/null
    xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$UDID" "$OLD_APP" && start "$UDID" "$RUNTIME-old-build"
    xcrun simctl install "$UDID" "$NEW_APP"
    start "$UDID" "$RUNTIME-new-build-1"
    start "$UDID" "$RUNTIME-new-build-2"
    xcrun simctl shutdown "$UDID" || true
    echo "::endgroup::"
done <<< "$SIMS"

for REPORT in $(ls -t ~/Library/Logs/DiagnosticReports/SweetArrows* 2>/dev/null | head -n 3); do
    echo "::group::Crash report $REPORT"
    head -n 160 "$REPORT"
    echo "::endgroup::"
done
exit $STATUS
