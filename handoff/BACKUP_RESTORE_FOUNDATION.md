# Backup / Restore Foundation

## Status

The backup/restore pipeline now covers versioned medication data, deterministic ZIP archives, photo attachment staging/commit/rollback, Riverpod composition, restored-state refresh, post-transaction reminder rebuild, and stale-stage maintenance triggered from app composition.

Implemented:

- versioned `BackupSnapshot` / `BackupRecord` models and Medication/DoseLog DTOs;
- deterministic JSON manifest and ZIP bundle codecs with attachment/path validation;
- `MedicationPhotoAttachmentCollector` and immutable backup attachments;
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
- focused tests for transaction ordering, rollback policy, filesystem safety, state refresh, and reminder rebuild behavior;
- pinned `archive` 4.0.9 dependency.

No share sheet or file picker is introduced yet.

## Boundary

```text
Presentation
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
- A future export share action hands the generated local archive to the OS share sheet; the user chooses the destination.
- Encryption/password protection remains a separate product/security decision.

## Next slices

1. Add retry/repair UX for `backup_restore_reminder_rebuild_failed`, `backup_restore_reminder_state_persist_failed`, and `backup_restore_reminder_cleanup_failed`.
2. Add export/share and import/file-selection presentation now that transactional restore and reminder repair semantics are defined.
3. Expand integration coverage for interrupted restores and reminder repair retries.
4. Consider whether resume-triggered maintenance is needed in addition to once-per-app-session cleanup after observing real-world restore/import usage.
