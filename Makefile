FLUTTER ?= flutter
DART ?= dart
DEVICE ?=

.PHONY: bootstrap configure-identifiers pub-get ensure-pub l10n-generate l10n-validate l10n-check \
	format format-check analyze test test-domain test-data test-presentation \
	test-suites test-all check android-build android-test android ios-build \
	ios-test ios ios-device-profile ios-device-release

bootstrap:
	./tool/bootstrap_platforms.sh

configure-identifiers:
	./tool/configure_identifiers.sh

pub-get:
	$(FLUTTER) pub get

ensure-pub:
	@if [ ! -f .dart_tool/package_config.json ]; then \
		echo "Resolving Flutter dependencies..."; \
		$(FLUTTER) pub get; \
	fi

l10n-generate: ensure-pub
	$(DART) run tool/generate_localizations.dart

l10n-validate: ensure-pub
	$(DART) run tool/validate_translations.dart

l10n-check: l10n-validate
	$(DART) run tool/generate_localizations.dart --check

format: ensure-pub
	$(DART) format lib test tool

format-check: ensure-pub
	$(DART) format --output=none --set-exit-if-changed lib test tool

analyze: ensure-pub
	$(FLUTTER) analyze

test: test-all

test-domain: ensure-pub
	$(FLUTTER) test test/medication_test.dart

test-data: ensure-pub
	$(FLUTTER) test test/csv_validator_test.dart test/photo_service_test.dart

test-presentation: ensure-pub
	$(FLUTTER) test test/repository_di_test.dart test/today_doses_provider_test.dart test/accessibility_test.dart

test-suites: test-domain test-data test-presentation

test-all: ensure-pub
	$(FLUTTER) test

check: l10n-check format-check analyze test-all

android-build: ensure-pub
	$(FLUTTER) build apk --debug

android-test: check android-build

android: android-test

ios-build: ensure-pub
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "iOS builds require macOS/Xcode."; \
		exit 1; \
	fi
	$(FLUTTER) build ios --simulator --debug

ios-test: check ios-build

ios: ios-test

ios-device-profile: ensure-pub
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "iOS device runs require macOS/Xcode."; \
		exit 1; \
	fi
	@if [ -z "$(DEVICE)" ]; then \
		echo "DEVICE is required. Example: make ios-device-profile DEVICE=00008030-0004694C3E68C02E"; \
		exit 1; \
	fi
	$(FLUTTER) run --profile -d "$(DEVICE)"

ios-device-release: ensure-pub
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "iOS device runs require macOS/Xcode."; \
		exit 1; \
	fi
	@if [ -z "$(DEVICE)" ]; then \
		echo "DEVICE is required. Example: make ios-device-release DEVICE=00008030-0004694C3E68C02E"; \
		exit 1; \
	fi
	$(FLUTTER) run --release -d "$(DEVICE)"
