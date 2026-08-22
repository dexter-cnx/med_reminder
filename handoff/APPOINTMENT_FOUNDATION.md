# Appointment Foundation Handoff

## Scope

This increment introduces Appointment as an independent Besyu feature boundary without making Timeline, Home, or medication own appointment data.

## Domain

`DoctorAppointment` is the source feature entity and currently contains:

- `id`
- `title`
- `startsAt`
- optional `endsAt`
- optional `location`
- optional `note`
- optional `externalCalendarEventId`

The external calendar identifier is linkage metadata only. The domain does not import or depend on a device-calendar plugin.

## Persistence

Appointment persistence follows the existing repository/data-source boundary:

```text
AppointmentRepository
        |
LocalAppointmentRepository
        |
AppointmentLocalDataSource
        |
HiveAppointmentLocalDataSource
```

`AppointmentRecord` schema version is currently `1`.

Repository behavior:

- `readAll()` returns appointments ordered by `startsAt`
- `upsert()` is idempotent by appointment ID at the data-source key level
- `delete()` removes only the appointment record
- read/write/delete failures return feature-specific `Failure` codes

## Presentation state

`appointmentsProvider` and `AppointmentViewModel` provide Riverpod state over the abstract repository.

The provider deliberately requires app DI and has no hidden Hive dependency.

## Timeline projection

`AppointmentTimelineItem` is now part of the Timeline read-model vocabulary.

`buildDailyTimeline()` accepts appointment inputs and can project them together with medication doses and refill events in chronological order.

Timeline remains a projection only; it does not persist appointment data.

## Runtime wiring policy

This PR intentionally does **not** add `appointmentsProvider` to the production `dailyTimelineProvider` yet.

Reason: app bootstrap must first open the dedicated appointment Hive box and override `appointmentRepositoryProvider`. Watching an unbound provider from the production timeline would make startup fail.

The next implementation step must wire these together atomically:

1. open a dedicated `appointments` Hive box in bootstrap;
2. construct `HiveAppointmentLocalDataSource`;
3. construct `LocalAppointmentRepository`;
4. override `appointmentRepositoryProvider` in the root `ProviderScope`;
5. watch `appointmentsProvider` from the app-level Timeline composition provider;
6. add Appointment create/edit/delete UI;
7. add localization keys for Appointment UI;
8. then add the optional device-calendar adapter behind an explicit port and user-confirmed action.

## Device calendar boundary

Do not put calendar-plugin calls in `DoctorAppointment`, repository implementations, or Flutter widgets directly.

Preferred next boundary:

```dart
abstract interface class AppointmentCalendarGateway {
  Future<String?> addToDeviceCalendar(DoctorAppointment appointment);
  Future<void> removeFromDeviceCalendar(String externalEventId);
}
```

The exact API may evolve. Calendar write operations must be explicit user actions and permission requests must remain contextual.

## Responsive UI

Appointment UI must follow `handoff/RESPONSIVE_UI.md`:

- Mobile and Tablet may use different composition;
- ratio/available-space signals remain primary;
- Tablet is not a scaled phone UI;
- portrait and landscape both require validation;
- fixed pixel values are safety guards rather than the main layout model.

## Tests

Current regression coverage verifies:

- appointment persistence round-trip;
- chronological repository ordering;
- location/note preservation;
- same-day Timeline filtering;
- `AppointmentTimelineItem` timestamp projection.

## Non-goals

- medical interpretation of appointment data;
- cloud sync;
- caregiver scheduling;
- automatic calendar writes;
- importing arbitrary calendar events into Besyu;
- appointment reminders before notification policy is explicitly designed.
