# Backup / Restore Foundation

## Status

The backup/restore pipeline now covers versioned medication data, deterministic ZIP archives, photo attachment staging/commit/rollback, Riverpod composition, restored-state refresh, post-transaction reminder rebuild, stale-stage maintenance, manual reminder repair UX, attachment-complete export coordination, OS share-sheet export, and validated import/replace-all presentation.

Implemented:

- versioned `BackupSnapshot` / `BackupRecord` models and Medication/DoseLog DTOs;
- deterministic JSON manifest and ZIP bundle codecs with attachment/path validation;
- `MedicationPhotoAttachmentCollector` and immutable backup attachments;
- `CreateBackupBundle` as capture → medication-photo collection → ZIP encoding, so exported backups match the bundle restore format and do not silently omit referenced medication photos;
- Riverpod `createBackupBundleProvider` composition using `FileBackupAttachmentSource` and `ZipBackupBundleArchiveCodec`;
- `BackupExportPort` and `SharePlusBackupExportPort` for handing a temporary ZIP to the OS share sheet without choosing or uploading a destination inside Besyu;
- provider-owned `BackupExportController` busy state so navigation cannot accidentally start concurrent exports;
- export controller coverage for share-sheet cancellation, transport failure, deterministic filenames, and concurrent-export rejection;
- neutral share-anchor coordinates passed to the adapter so iPad popover presentation stays safe without importing Flutter UI geometry into the application contract;
- Settings export card with offline/privacy copy and user-controlled destination selection;
- shared ZIP files retained for 24 hours so Android share recipients can consume the URI asynchronously, with stale files removed best-effort on a later export;
- dismissed share sheets return `backup_export_cancelled` instead of being reported as successful exports;
- `BackupImportPort` and `FilePickerBackupImportPort` for selecting one ZIP archive through the native file picker;
- import archives capped at 256 MiB before/after byte loading to bound the current in-memory restore architecture;
- provider-owned `BackupImportController` that decodes and validates the selected ZIP before any restore mutation and exposes a medication/dose-log/photo preview;
- explicit replace-all confirmation showing file/export metadata and record counts before `RestoreBackupBundle` is invoked;
- picker cancellation is a normal no-op; selecting a file alone never changes application data;
- post-restore reminder failures are surfaced as “data restored, reminders need repair” instead of incorrectly presenting the whole restore as rolled back;
- `BackupAttachmentRestorePort` stage / commit / rollback / discard semantics;
- `FileBackupAttachmentRestorePort` with isolated staging, collision-safe `med_photos` destinations, symlink-aware containment, persistent stage metadata, and stale-stage cleanup;
- `PrepareBackupRestore` and `CommitPreparedBackupRestore` with repository/file compensation rules;
- prepared restore stages are discarded immediately when pre-commit reminder-state capture fails, with an explicit cleanup failure if the stage cannot be removed;
- preservation of committed photos when repository rollback itself fails, avoiding known dangling photo paths;
- `RestoreBackupBundle` as the end-to-end decode → stage → file commit → atomic data restore coordinator;
- Riverpod composition that refreshes medication/dose-log state after durable restore;
- `RebuildRestoredReminders` as a post-transaction repair step that derives new notification IDs from restored medication data rather than trusting backup IDs;
- explicit post-restore reminder repair failures without rolling durable restored data/files back;
- stale restore staging cleanup triggered when the operational Home composition is first mounted in an app ProviderScope;
- maintenance cleanup remains asynchronous and non-blocking so cleanup failure cannot turn into startup/UI failure;
- manual reminder repair in Settings with provider-owned busy state and user-facing failure semantics;
- focused tests for transaction ordering, rollback policy, filesystem safety, state refresh, reminder rebuild behavior, import/export controller lifecycle, and bundle export orchestration;
- pinned `archive` 4.0.9 dependency.

## Boundary

```text
Settings export card
        ↓
backupExportControllerProvider
        ↓
createBackupBundleProvider
        ↓
CreateBackupBundle
        ↓
MedicationBackupDataPort.capture()
        ↓
MedicationPhotoAttachmentCollector
        ↓
ZipBackupBundleArchiveCodec.encodeBundle()
        ↓
complete local ZIP bytes
        ↓
SharePlusBackupExportPort
        ↓
retained temporary ZIP → OS share sheet → user-selected destination

Settings import card
        ↓
backupImportControllerProvider
        ↓
FilePickerBackupImportPort
        ↓
selected ZIP bytes
        ↓
ZipBackupBundleArchiveCodec.decodeBundle()
        ↓
validated preview (exportedAt + medication/log/photo counts)
        ↓
explicit replace-all confirmation
        ↓
restoreBackupBundleProvider
        ↓
RestoreBackupBundle
        ↓
PrepareBackupRestore
        ↓
ZipBackupBundleArchiveCodec + FileBackupAttachmentRestorePort.stage()
        ↓
pre-commit reminder-state capture
        ↓
(capture failure → discard staged attachments)
        ↓
CommitPreparedBackupRestore
        ↓
FileBackupAttachmentRestorePort.commit()
        ↓
MedicationBackupDataPort.restoreAtomically()
        ↓
durable restored data/files
        ↓
RebuildRestoredReminders
        ↓
new derived notification IDs persisted locally
        ↓
Riverpod medication/log state refreshed

Home app composition
        ↓
backupRestoreMaintenanceProvider
        ↓
FileBackupAttachmentRestorePort.cleanupStaleStages(24h)
```

`backup.json` remains authoritative for backed-up application data. Archive-relative attachment paths, temporary stage paths, exported notification IDs, and picker cache paths are never authoritative live state.

## Restore safety

Restore uses replace-all semantics for the first product version.

The restore transaction preserves these invariants:

1. selecting a file does not mutate repositories or live photos;
2. decode/validate the selected ZIP before presenting the replace-all action;
3. require an explicit replace-all confirmation before invoking the restore coordinator;
4. validate archive structure and schema again inside the transactional restore path before mutation;
5. stage every referenced file and reserve final photo paths before repository replacement;
6. if staging/rewrite fails, discard the stage and leave repositories untouched;
7. if reminder-state capture fails after preparation but before commit, discard the stage immediately and leave repositories untouched;
8. commit staged files before repository replacement;
9. if file commit fails, do not mutate repositories;
10. if repository replacement fails and repository rollback is complete, remove committed restore files;
11. if repository rollback itself fails, preserve committed photos because surviving records may reference them;
12. refresh Riverpod medication/log state after durable restore so stale in-memory state cannot overwrite restored repositories;
13. rebuild reminders only after data/files are durably restored;
14. reminder rebuild failure does not roll restored data/files back; it returns a dedicated repair failure so the UI can tell the user reminders need retry/repair;
15. notification IDs remain derived operational state and are regenerated locally;
16. stale-stage cleanup removes only staging directories older than 24 hours and is maintenance-only/non-blocking.

A partially applied data/file restore is not acceptable. A reminder repair failure is different: application data is already durably restored and must remain so.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- Sensitive health data or attachment paths/content must not be logged to analytics or crash breadcrumbs.
- Export/share writes a ZIP under app temporary storage and hands it to the OS share sheet; the user chooses the destination.
- Shared ZIP files are retained for 24 hours because receiving apps may consume the shared URI after the share intent returns; later exports remove stale files best-effort.
- Dismissing the share sheet is treated as cancellation and is not presented as a successful backup export.
- Import uses the OS file picker and reads the selected ZIP locally; selecting or cancelling never uploads data.
- Encryption/password protection remains a separate product/security decision.

## Next slices

1. Expand filesystem-level interrupted-restore coverage around persisted staging metadata and app-restart cleanup.
2. Add platform-adapter coverage for file-picker read errors and share-sheet unavailable/error outcomes where test seams permit.
3. Consider moving large archives away from whole-file in-memory restore if real backups approach the current 256 MiB import guard.
4. Consider whether resume-triggered maintenance is needed in addition to once-per-app-session cleanup after observing real-world restore/import usage.
