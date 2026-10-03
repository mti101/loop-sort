#!/usr/bin/env bash
# Recreates the Android scaffold (run once after cloning, needs Flutter SDK).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --org com.terafort --project-name loopsort --platforms android --no-pub .
rm -f test/widget_test.dart.orig
python3 tools/ci/patch_android.py
flutter pub get
