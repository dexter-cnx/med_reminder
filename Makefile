.PHONY: bootstrap pub-get l10n-generate l10n-check format format-check analyze test check

bootstrap:
	./tool/bootstrap_platforms.sh

pub-get:
	flutter pub get

l10n-generate:
	dart run tool/generate_localizations.dart

l10n-check:
	dart run tool/generate_localizations.dart --check

format:
	dart format lib test tool

format-check:
	dart format --output=none --set-exit-if-changed lib test tool

analyze:
	flutter analyze

test:
	flutter test

check: l10n-check format-check analyze test
