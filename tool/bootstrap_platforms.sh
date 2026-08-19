#!/usr/bin/env bash
set -euo pipefail

command -v flutter >/dev/null 2>&1 || { echo "flutter is required" >&2; exit 1; }
flutter --version

[[ -f pubspec.yaml && -d lib && -d tool ]] || {
  echo "Run this script from the med_reminder repository root." >&2
  exit 1
}

if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before bootstrap." >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="tool/.bootstrap_backup/$timestamp"
mkdir -p "$backup_root"
cp -R lib "$backup_root/lib"
[[ -d assets ]] && cp -R assets "$backup_root/assets"
[[ -d test ]] && cp -R test "$backup_root/test"
printf '%s\n' "Backup created at $backup_root"

restore_sources() {
  rm -rf lib
  cp -R "$backup_root/lib" lib
  if [[ -d "$backup_root/assets" ]]; then
    rm -rf assets
    cp -R "$backup_root/assets" assets
  fi
  if [[ -d "$backup_root/test" ]]; then
    rm -rf test
    cp -R "$backup_root/test" test
  fi
}

trap 'restore_sources; echo "Bootstrap failed; source backup kept at $backup_root" >&2' ERR

flutter create \
  --project-name med_reminder_offline \
  --org com.cnxdev \
  --platforms=android,ios \
  .

restore_sources
trap - ERR

python3 - <<'PY'
from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text()
manifest_tag = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
permissions = [
    '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
    '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />',
]
for permission in permissions:
    if permission not in text:
        text = text.replace(manifest_tag, manifest_tag + '\n    ' + permission)

receivers = '''
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false" />
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
'''
if 'ScheduledNotificationReceiver' not in text:
    text = text.replace('    </application>', receivers + '    </application>')
manifest.write_text(text)

plist = Path('ios/Runner/Info.plist')
text = plist.read_text()
if '<key>NSCameraUsageDescription</key>' not in text:
    text = text.replace(
        '</dict>',
        '\t<key>NSCameraUsageDescription</key>\n'
        '\t<string>Take a medication package photo for on-device storage.</string>\n'
        '</dict>',
    )
plist.write_text(text)
PY

echo "Android/iOS scaffolding created."
echo "Source backup retained at: $backup_root"
echo "Delete it manually after verifying the generated platform projects."
