# Backup / Restore Foundation

## Status

The backup/restore pipeline now covers versioned medication data, deterministic ZIP archives, photo attachment staging/commit/rollback, Riverpod composition, restored-state refresh, post-transaction reminder rebuild, stale-stage maintenance, manual reminder repair UX, attachment-complete export coordination, and OS share-sheet export presentation.

Implemented:

- versioned `BackupSnapshot` / `BackupRecord` models and Medication/DoseLog DTOs;
- deterministic JSON manifest and ZIP bundle codecs with attachment/path validation;
- `MedicationPhotoAttachmentCollector` and immutable backup attachments;
- `CreateBackupBundle` as capture → medication-photo collection → ZIP encoding, so exported backups match the bundle restore format and do not silently omit referenced medication photos;
- Riverpod `createBackupBundleProvider` composition using `FileBackupAttachmentSource` and `ZipBackupBundleArchiveCodec`;
- `BackupExportPort` and `SharePlusBackupExportPort` for handing a temporary ZIP to the OS share sheet without choosing or uploading a destination inside Besyu;
- provider-owned `BackupExportController` busy state so navigation cannot accidentally start concurrent exports;
- neutral share-anchor coordinates passed to the adapter so iPad popover presentation stays safe without importing Flutter UI geometry into the application contract;
- Settings export card with offline/privacy copy and user-controlled destination selection;
- `BackupAttachmentRestorePort` stage / commit / rollback / discard semantics;
- `FileBackupAttachmentRestorePort` with isolated staging, collision-safe `med_photos` destinations, symlink-aware containment, persistent stage metadata, and stale-stage cleanup;
- `PrepareBackupRestore` and `CommitPreparedBackupRestore` with repository/file compensation rules;
- preservation of committed photos when repository rollback itself fails, avoiding known dangling photo paths;
- `RestoreBackupBundle` as the end-to-end decode → stage → file commit → atomic data restore coordinator;
- Riverpod composition that refreshes medication/dose-log state after durable restore;
- `RebuildRestoredReminders` as a post-transaction repair step that derives new notification IDs from restored medication data rather than trusting backup IDs;
- explicit post-restore reminder repair failures without rolling durable restored data/files back;
- stale restore staging cleanup triggered when the operational Home composition is first mounted in an app ProviderScope;
- maintenance cleanup remains asynchronous and non-blocking so cleanup failure cannot turn into startup/UI failure;
- manual reminder repair in Settings with provider-owned busy state and user-facing failure semantics;
- focused tests for transaction ordering, rollback policy, filesystem safety, state refresh, reminder rebuild behavior, and bundle export orchestration;
- pinned `archive` 4.0.9 dependency.

No import file picker is introduced yet.

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
temporary ZIP → OS share sheet → user-selected destination

Import presentation (next slice)
        ↓
restoreBackupBundleProvider
        ↓
RestoreBackupBundle
        ↓
PrepareBackupRestore
        ↓
ZipBackupBundleArchiveCodec + FileBackupAttachmentRestorePort.stage()
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

`backup.json` remains authoritative for backed-up application data. Archive-relative attachment paths, temporary stage paths, and exported notification IDs are never authoritative live state.

## Restore safety

Restore uses replace-all semantics for the first product version.

The restore transaction preserves these invariants:

1. validate archive structure and schema before mutation;
2. stage every referenced file and reserve final photo paths before repository replacement;
3. if staging/rewrite fails, discard the stage and leave repositories untouched;
4. commit staged files before repository replacement;
5. if file commit fails, do not mutate repositories;
6. if repository replacement fails and repository rollback is complete, remove committed restore files;
7. if repository rollback itself fails, preserve committed photos because surviving records may reference them;
8. refresh Riverpod medication/log state after durable restore so stale in-memory state cannot overwrite restored repositories;
9. rebuild reminders only after data/files are durably restored;
10. reminder rebuild failure does not roll restored data/files back; it returns a dedicated repair failure so the UI can tell the user reminders need retry/repair;
11. notification IDs remain derived operational state and are regenerated locally;
12. stale-stage cleanup removes only staging directories older than 24 hours and is maintenance-only/non-blocking.

A partially applied data/file restore is not acceptable. A reminder repair failure is different: application data is already durably restored and must remain so.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- Sensitive health data or attachment paths/content must not be logged to analytics or crash breadcrumbs.
- Export/share writes only a temporary ZIP and hands it to the OS share sheet; the user chooses the destination.
- Temporary share files are removed on a best-effort basis after the share action completes.
- Encryption/password protection remains a separate product/security decision.

## Next slices

1. Add import/file-selection presentation that reads selected ZIP bytes and calls `restoreBackupBundleProvider` with explicit replace-all confirmation.
2. Add cancellation/error UX for file picking and restore confirmation.
3. Expand integration coverage for interrupted restores and file-transfer cancellation/error cases.
4. Consider whether resume-triggered maintenance is needed in addition to once-per-app-session cleanup after observing real-world restore/import usage.
