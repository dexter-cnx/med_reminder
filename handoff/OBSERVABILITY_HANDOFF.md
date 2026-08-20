# Observability Handoff

## Status

Planned architecture only. **Do not integrate any concrete analytics or crash-reporting SDK yet.**

The goal is to make analytics and crash reporting replaceable infrastructure concerns rather than application dependencies. Product/domain/presentation code must never import Firebase Analytics, Sentry, Crashlytics, PostHog, AppCenter, or any other vendor SDK directly.

## Architecture goal

Introduce a small application-facing observability boundary with provider adapters selected only at the composition root through Riverpod.

```text
App / Features / ViewModels
        |
        v
Observability ports
  |- AnalyticsTracker
  |- CrashReporter
        |
        v
Adapters
  |- NoopAnalyticsAdapter          (initial/default)
  |- NoopCrashReporterAdapter      (initial/default)
  |- FirebaseAnalyticsAdapter      (future example)
  |- PostHogAnalyticsAdapter       (future example)
  |- SentryCrashReporterAdapter    (future example)
  |- CrashlyticsReporterAdapter    (future example)
        |
        v
Vendor SDKs
```

The dependency direction is important: vendor implementations depend on the app-owned contracts, never the reverse.

## Proposed contracts

Names are intentionally generic. Final API can be adjusted when implementation starts, but the boundary should remain provider-neutral.

```dart
abstract interface class AnalyticsTracker {
  Future<void> trackEvent(
    String name, {
    Map<String, Object?> properties = const {},
  });

  Future<void> setUserProperty(String name, Object? value);

  Future<void> setUserId(String? userId);

  Future<void> reset();
}

abstract interface class CrashReporter {
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    Map<String, Object?> context = const {},
  });

  Future<void> recordMessage(
    String message, {
    Map<String, Object?> context = const {},
  });

  Future<void> setUserId(String? userId);

  Future<void> setContext(String key, Object? value);
}
```

Do not expose vendor-specific concepts such as Firebase event classes, Sentry scopes, breadcrumbs, Crashlytics keys, or SDK-specific result types through these contracts.

## Initial implementation strategy

When the abstraction is introduced, the first concrete implementations should be no-op adapters:

```text
NoopAnalyticsAdapter
NoopCrashReporterAdapter
```

This lets application code use the contracts without adding network behavior, tracking, consent requirements, vendor configuration, native setup, or new runtime dependencies.

Riverpod should own composition, for example conceptually:

```dart
final analyticsTrackerProvider = Provider<AnalyticsTracker>(
  (ref) => const NoopAnalyticsAdapter(),
);

final crashReporterProvider = Provider<CrashReporter>(
  (ref) => const NoopCrashReporterAdapter(),
);
```

Tests can override these providers with recording/fake adapters.

## Event ownership

Analytics event names must be app-owned constants/value objects, not strings scattered throughout widgets.

Prefer a small typed or centrally defined event catalog such as:

```text
app_opened
onboarding_completed
medication_created
medication_updated
medication_deleted
reminder_snoozed
reminder_marked_taken
reminder_skipped
doctor_appointment_created
```

This list is illustrative, not a requirement to implement tracking now.

Feature code should report meaningful product/domain outcomes rather than low-level UI gestures unless a UX question explicitly needs them.

Example: prefer `medication_created` after successful persistence instead of `add_button_tapped` before validation/storage completes.

## Crash reporting boundary

Crash reporting should be independent from product analytics. A future implementation may use different vendors for each concern.

Recommended future bootstrap flow:

1. Install framework-level error capture at the app boundary.
2. Forward uncaught Flutter framework errors to `CrashReporter`.
3. Forward uncaught asynchronous/platform errors to `CrashReporter`.
4. Keep explicit recoverable failures inside the existing `Result<T>` / `Failure` flow; report only when useful for diagnosis.
5. Never require the crash-reporting provider to be available for app startup to succeed.

The app must continue functioning if the crash-reporting adapter fails, is disabled, has no network, or is replaced with a no-op adapter.

## Privacy and medication-data rules

Because this app handles medication-related information, analytics/crash payloads must be conservative by default.

Do **not** send raw medication names, prescription labels, photos, OCR text, doctor notes, free-form user input, notification bodies, filesystem paths containing user data, or other health-related content to analytics/crash vendors unless a future privacy review explicitly approves it.

Prefer coarse technical/product metadata such as:

```text
schedule_type = daily | finite | until_empty
operation = create | edit | delete
result = success | failure
platform = android | ios
feature = medication | reminders | appointments
```

Error objects may accidentally contain sensitive data, so future crash adapters should support sanitization/redaction before transmission.

## Consent and enable/disable policy

Do not couple the app to the assumption that analytics is always enabled.

The architecture should allow:

- analytics enabled/disabled independently;
- crash reporting enabled/disabled independently;
- runtime replacement with a no-op adapter;
- future user/privacy settings without changing feature code;
- build-flavor selection if needed;
- offline-first operation when no telemetry provider exists.

If consent is required by the chosen provider, consent handling belongs above the provider adapter and the adapter must respect the resulting enabled state.

## Future provider examples

Potential analytics adapters:

- Firebase Analytics
- PostHog
- Amplitude
- Mixpanel
- self-hosted/internal analytics

Potential crash adapters:

- Firebase Crashlytics
- Sentry
- Bugsnag
- another provider or internal collector

These are examples only. **No provider is selected by this handoff.**

A single vendor may implement both ports, but the two contracts must remain separate so either side can be replaced independently.

## Testing requirements for future implementation

When the abstraction is implemented:

- add recording/fake adapters for unit and ViewModel tests;
- verify a successful business action emits the expected event exactly once;
- verify failed persistence does not emit a success event;
- verify adapter exceptions do not break application flows;
- verify no-op adapters are safe and side-effect free;
- verify sensitive payload filtering/redaction;
- avoid tests that require a real vendor SDK or network connection.

## Suggested project location

Exact paths may follow the final project structure, but keep the boundary outside feature-specific infrastructure if it is shared app-wide. A reasonable future shape is:

```text
lib/core/observability/
├── analytics_tracker.dart
├── crash_reporter.dart
├── analytics_event.dart
└── adapters/
    ├── noop_analytics_adapter.dart
    ├── noop_crash_reporter_adapter.dart
    └── ...future vendor adapters
```

Alternatively the contracts may live under an application/shared domain boundary while concrete adapters live in infrastructure/data. The important constraint is dependency direction, not the exact folder name.

## Explicit non-goals for now

- Do not add Firebase/Sentry/PostHog/etc. packages.
- Do not modify Android/iOS native configuration for telemetry.
- Do not send events or crashes anywhere.
- Do not add consent UI yet.
- Do not instrument screens/features yet.
- Do not make analytics or crash reporting a startup dependency.

This handoff exists so future implementation can add observability without coupling Besyu to a specific provider.