#!/usr/bin/env bash
set -euo pipefail
adb install --abi arm64-v8a /tmp/Child.apk
python3 device-tests/child_tracking.py || STATUS=$?
adb logcat -d >device-results/child-logcat.txt
exit "${STATUS:-0}"
