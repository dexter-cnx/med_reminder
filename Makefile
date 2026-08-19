.PHONY: bootstrap pub-get ensure-pub l10n-generate l10n-validate l10n-check format format-check analyze test check

bootstrap:
	./tool/bootstrap_platforms.sh

pub-get:
	flutter pub get

ensure-pub:
	@if [ ! -f .dart_tool/package_config.json ]; then \
		echo "Resolving Flutter dependencies..."; \
		flutter pub get; \
	fi

l10n-generate: ensure-pub
	dart run tool/generate_localizations.dart

l10n-validate: ensure-pub
	dart run tool/validate_translations.dart

l10n-check: l10n-validate
	dart run tool/generate_localizations.dart --check

format: ensure-pub
	dart format lib test tool

format-check: ensure-pub
	dart format --output=none --set-exit-if-changed lib test tool

analyze: ensure-pub
	flutter analyze

test: ensure-pub
	flutter test

check: l10n-check format-check analyze test
