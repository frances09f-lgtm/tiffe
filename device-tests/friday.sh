#!/usr/bin/env bash
set -euo pipefail
exec > >(tee device-results/friday-ui.log) 2>&1
adb shell getprop ro.build.version.release
adb install --abi arm64-v8a /tmp/Friday.apk
adb shell pm grant com.friday.assistant android.permission.POST_NOTIFICATIONS || true
adb shell pm grant com.friday.assistant android.permission.RECORD_AUDIO || true
adb shell pm grant com.friday.assistant android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant com.friday.assistant android.permission.ACCESS_COARSE_LOCATION || true
adb shell pm grant com.friday.assistant android.permission.READ_CONTACTS || true
adb shell settings put secure enabled_accessibility_services com.friday.assistant/com.friday.assistant.FridayAccessibilityService
adb shell settings put secure accessibility_enabled 1
python3 device-tests/friday_ui.py || STATUS=$?
adb shell dumpsys accessibility >device-results/accessibility.txt
adb logcat -d >device-results/friday-logcat.txt
exit "${STATUS:-0}"
