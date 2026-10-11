#!/usr/bin/env bash
set -euo pipefail
exec > >(tee device-results/probe.log) 2>&1
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.dalvik.vm.native.bridge
adb install /tmp/Friday.apk
adb shell monkey -p com.friday.assistant -c android.intent.category.LAUNCHER 1
sleep 12
adb shell uiautomator dump /sdcard/window.xml
adb pull /sdcard/window.xml device-results/friday-launch.xml
adb exec-out screencap -p >device-results/friday-launch.png
adb shell settings put secure enabled_accessibility_services com.friday.assistant/com.friday.assistant.FridayAccessibilityService
adb shell settings put secure accessibility_enabled 1
sleep 4
adb shell dumpsys accessibility >device-results/accessibility.txt
adb logcat -d >device-results/friday-logcat.txt
adb install /tmp/Child.apk
adb shell monkey -p com.childsafety.child_safety_tracker -c android.intent.category.LAUNCHER 1
sleep 8
adb shell uiautomator dump /sdcard/window.xml
adb pull /sdcard/window.xml device-results/child-launch.xml
adb exec-out screencap -p >device-results/child-launch.png
adb logcat -d >device-results/final-logcat.txt
