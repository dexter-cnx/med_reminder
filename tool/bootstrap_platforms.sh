#!/usr/bin/env bash
set -euo pipefail
command -v flutter >/dev/null 2>&1 || { echo "flutter is required" >&2; exit 1; }

flutter create \
  --project-name med_reminder_offline \
  --org com.cnxdev \
  --platforms=android,ios \
  .

python3 - <<'PY'
from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text()
permission = '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />'
if permission not in text:
    text = text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + permission)
manifest.write_text(text)

plist = Path('ios/Runner/Info.plist')
text = plist.read_text()
if '<key>NSCameraUsageDescription</key>' not in text:
    marker = '</dict>'
    addition = '\t<key>NSCameraUsageDescription</key>\n\t<string>Take a medication package photo for on-device storage.</string>\n'
    text = text.replace(marker, addition + marker)
plist.write_text(text)
PY

echo "Android/iOS scaffolding created and reminder/camera permissions patched. Review signing and bundle IDs before device builds."
