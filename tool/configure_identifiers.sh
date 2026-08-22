#!/usr/bin/env bash
set -euo pipefail

IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.cnxdev.besyu}"
IOS_TEAM_ID="${IOS_TEAM_ID:-ZTM9BCJPY9}"
ANDROID_APP_ID="${ANDROID_APP_ID:-com.cnxdev.besyu}"

python3 - <<'PY'
import os
from pathlib import Path

bundle_id = os.environ.get('IOS_BUNDLE_ID', 'com.cnxdev.besyu')
team_id = os.environ.get('IOS_TEAM_ID', 'ZTM9BCJPY9')
android_app_id = os.environ.get('ANDROID_APP_ID', 'com.cnxdev.besyu')

pbxproj = Path('ios/Runner.xcodeproj/project.pbxproj')
if pbxproj.exists():
    text = pbxproj.read_text()
    text = text.replace('com.cnxdev.beside_you', bundle_id)
    text = text.replace('com.cnxdev.med_reminder_offline', bundle_id)
    text = text.replace('DEVELOPMENT_TEAM = VRL8N6A823;', f'DEVELOPMENT_TEAM = {team_id};')
    text = text.replace('DEVELOPMENT_TEAM = ZTM9BCJPY9;', f'DEVELOPMENT_TEAM = {team_id};')
    pbxproj.write_text(text)

android_gradle = Path('android/app/build.gradle.kts')
if android_gradle.exists():
    text = android_gradle.read_text()
    for old in ('com.example.med_reminder_offline', 'com.cnxdev.med_reminder_offline', 'com.cnxdev.beside_you'):
        text = text.replace(old, android_app_id)
    android_gradle.write_text(text)
PY

echo "Configured identifiers:"
echo "  iOS bundle: $IOS_BUNDLE_ID"
echo "  iOS team:   $IOS_TEAM_ID"
echo "  Android ID: $ANDROID_APP_ID"
