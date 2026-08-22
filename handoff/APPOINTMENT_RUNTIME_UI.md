# Appointment Runtime + UI Handoff

## Scope

This increment activates the Appointment foundation in the production runtime and exposes appointment management without coupling the feature to a device-calendar plugin.

## Runtime persistence

Besyu now opens a dedicated Hive box:

```text
appointments
```

Root DI wires:

```text
HiveAppointmentLocalDataSource
-> LocalAppointmentRepository
-> appointmentRepositoryProvider
-> appointmentsProvider
```

Appointment remains the source owner for its persisted records.

## Daily Timeline integration

The app-level `dailyTimelineProvider` now watches `appointmentsProvider` and supplies those domain records to `buildDailyTimeline()`.

```text
Medication/DoseLog ----\
RefillEvent ------------> dailyTimelineProvider -> buildDailyTimeline -> Home Today
DoctorAppointment ------/
```

Timeline stays a projection only. It does not read the appointment Hive box directly.

## Appointment UI

Home now has a dedicated **Appointments** destination.

Supported operations:

- create appointment
- edit appointment
- delete appointment
- title
- date/time
- optional location
- optional note

Editing an appointment that already has an `endsAt` preserves its duration when the start time changes.

## Responsive behavior

The UI follows `handoff/RESPONSIVE_UI.md`.

### Mobile

- appointment list uses the available width
- editor is presented as a scrollable modal bottom sheet
- keyboard insets keep form controls/actions reachable

### Tablet

- appointment list is bounded to about 78% of available width
- appointment editor is bounded to about 62% of available width
- no phone form is stretched edge-to-edge

The shared ratio-first classifier remains the source for Mobile/Tablet classification.

## Calendar boundary

`AppointmentCalendarGateway` is now the explicit port for future platform-calendar integration.

```dart
abstract interface class AppointmentCalendarGateway {
  Future<String?> upsert(DoctorAppointment appointment);
  Future<void> deleteExternalEvent(String externalEventId);
}
```

Rules:

- local appointment persistence does not depend on device calendar availability
- no calendar permission is requested during bootstrap
- no background or automatic calendar write
- platform calendar writes must be initiated by an explicit user action
- returned external event identifiers may be stored in `externalCalendarEventId`
- calendar adapter/plugin choice remains replaceable

This increment intentionally does not expose an "Add to calendar" action until a real platform implementation exists, so the UI does not imply a capability that is not wired.

## Localization

Appointment navigation and editor labels are available in English and Thai through the existing CSV-generated localization pipeline.

## Regression coverage

Coverage now includes the runtime provider flow:

```text
AppointmentRepository
-> appointmentsProvider upsert/delete
-> buildDailyTimeline appointment projection
```

Existing foundation tests continue to cover record persistence, repository ordering, and day filtering.

## Next step

Implement a platform calendar adapter behind `AppointmentCalendarGateway`, then expose an explicit user-confirmed action from the appointment editor/detail surface. Keep calendar permission requests lazy and action-scoped.
