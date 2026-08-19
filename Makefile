.PHONY: bootstrap pub-get format format-check analyze test check

bootstrap:
	./tool/bootstrap_platforms.sh

pub-get:
	flutter pub get

format:
	dart format lib test

format-check:
	dart format --output=none --set-exit-if-changed lib test

analyze:
	flutter analyze

test:
	flutter test

check: format-check analyze test
