# Code Walkthrough

## Data model

`Medication` owns schedule configuration, stock, duration mode, persistent photo path, and the exact notification IDs currently scheduled for it. `DoseLog` is keyed semantically by `medId + scheduledAt`; a morning dose and evening dose therefore remain independent.

## Scheduling

`NotificationService.scheduleForMed()` cancels the medication's previously persisted IDs first. `forever` and `untilEmpty` use daily recurring notifications. `untilEmpty` differs in lifecycle: when stock reaches zero the notifier cancels the saved notification IDs. `days` schedules finite one-shot notifications for each configured day.

IDs use a stable FNV-1a-style hash instead of Dart `String.hashCode`, so persisted cancellation IDs do not depend on a process-local hash implementation.

## Stock

Taking a dose writes a `taken` log and decrements stock without going below zero. Low-stock notification is emitted only when stock crosses the configured threshold. For `untilEmpty`, reaching zero cancels future recurring reminders.

## Snooze

Snooze is an upsert on the original scheduled dose and creates a one-shot reminder ten minutes later with a deterministic snooze ID. Taking or skipping that scheduled dose cancels the outstanding snooze notification.

## Photos

`PhotoService.persistPhoto()` copies the image-picker source into `<ApplicationDocuments>/med_photos/<uuid>.<ext>`. Removing medication also removes its owned image file.

## Localization

`SingleCsvAssetLoader` parses a single CSV, discovers locale codes from its header, supports quoted commas and escaped double quotes, and falls back to English when the selected language cell is empty.
