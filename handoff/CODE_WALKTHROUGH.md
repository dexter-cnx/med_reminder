# Code Walkthrough

## Architecture

The medication feature uses pragmatic Clean Architecture with MVVM and Riverpod as the dependency-injection/composition mechanism.

```text
features/medication/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── services/
├── data/
│   ├── datasources/
│   ├── models/
│   ├── repositories/
│   └── services/
└── presentation/
    └── viewmodels/
```

Dependency direction is inward: domain has no Flutter, Riverpod, or Hive imports. Data implements domain contracts. Presentation depends on domain contracts and Riverpod. `main.dart` is the composition root and injects concrete Hive/local implementations through `ProviderScope.overrides`.

Legacy paths under `lib/models`, `lib/providers`, and `lib/repositories` are compatibility exports while callers transition to the feature-first paths; new implementation logic belongs under `features/medication`.

## Domain model

`Medication` owns schedule configuration, stock, duration mode, persistent photo path, and the exact notification IDs currently scheduled for it. `DoseLog` is keyed semantically by `medId + scheduledAt`; a morning dose and evening dose therefore remain independent.

Domain entities contain no Hive serialization. `MedicationRecord` and `DoseLogRecord` in the data layer own persistence mapping and backward migration from the earlier log schema.

## Storage boundary

`MedicationRepository` and `DoseLogRepository` are domain contracts. `MedicationLocalDataSource` is the data-source boundary. `HiveMedicationLocalDataSource` is currently the concrete storage implementation, while `LocalMedicationRepository` and `LocalDoseLogRepository` map stored records to domain entities.

Because Riverpod injects the repository contracts, tests or future implementations can replace Hive with in-memory, SQLite, or another local store without changing the ViewModel or UI.

## MVVM

`MedicationViewModel` and `DoseLogViewModel` expose medication and dose-log state through Riverpod `StateNotifierProvider`s. They depend on repository and service ports rather than Hive or static notification/photo implementations.

`MedicationReminderScheduler` and `MedicationPhotoStore` are domain-facing ports. Local adapters bridge them to the current notification and file-storage services.

## Scheduling

The local notification adapter uses `NotificationService.scheduleForMed()`. `forever` and `untilEmpty` use daily recurring notifications. `untilEmpty` differs in lifecycle: when stock reaches zero the ViewModel cancels the saved notification IDs through `MedicationReminderScheduler`. `days` schedules finite one-shot notifications for each configured day.

IDs use a stable FNV-1a-style hash instead of Dart `String.hashCode`, so persisted cancellation IDs do not depend on a process-local hash implementation.

## Stock

Taking a dose writes a `taken` log and decrements stock without going below zero. Low-stock notification is emitted only when stock crosses the configured threshold. For `untilEmpty`, reaching zero cancels future recurring reminders.

## Snooze

Snooze is an upsert on the original scheduled dose and creates a one-shot reminder ten minutes later with a deterministic snooze ID. Taking or skipping that scheduled dose cancels the outstanding snooze notification.

## Photos

`PhotoService.persistPhoto()` copies the image-picker source into `<ApplicationDocuments>/med_photos/<uuid>.<ext>`. Deletion is exposed to the ViewModel through the `MedicationPhotoStore` port.

## Localization

`SingleCsvAssetLoader` parses a single CSV, discovers locale codes from its header, supports quoted commas and escaped double quotes, and falls back to English when the selected language cell is empty.
