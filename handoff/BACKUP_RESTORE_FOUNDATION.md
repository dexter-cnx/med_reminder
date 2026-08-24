# Backup / Restore Foundation

## Status

The backup/restore work now has the application boundary, feature-owned versioned DTO adapters, a concrete Medication/DoseLog data port, focused restore-safety coverage, a versioned JSON manifest codec, deterministic ZIP containers, and a photo-attachment collection + ZIP bundle boundary for the fully offline export/import flow.

Implemented:

- versioned `BackupSnapshot` model;
- namespace-based `BackupRecord` model so Backup does not import feature persistence implementations;
- deeply immutable backup record payloads;
- `BackupArchiveCodec` and `BackupBundleArchiveCodec` contracts;
- `BackupDataPort` contract for capturing application-owned data and restoring it atomically;
- `CreateBackup` and `RestoreBackup` use cases;
- schema validation before restore mutation;
- versioned Medication and DoseLog backup DTO conversion;
- Medication backup deliberately excludes notification IDs because notification schedules are derived state;
- concrete `MedicationBackupDataPort` with full preflight and compensating rollback;
- capture filtering so orphan DoseLogs are not exported;
- deterministic `JsonBackupArchiveCodec` and versioned `backup.json` manifest;
- deterministic `ZipBackupArchiveCodec` for manifest-only archives;
- `BackupAttachmentSource` and `FileBackupAttachmentSource` boundaries;
- `MedicationPhotoAttachmentCollector` converting local photo paths into deterministic `attachments/medication/<encoded-medication-id>.<ext>` references;
- immutable attachment bytes with defensive-copy access;
- `ZipBackupBundleArchiveCodec` that writes the manifest and collected attachment bytes into one deterministic ZIP;
- bundle decode preflight requiring every medication photo reference to be a safe archive-relative attachment path;
- rejection of missing referenced attachments, unexpected/unreferenced attachment entries, duplicate paths, path traversal/backslash paths, and corrupt ZIPs;
- focused attachment collection and ZIP bundle round-trip/failure-path tests;
- pinned `archive` 4.0.9 dependency.

No share sheet, file picker, live attachment extraction/commit, final local photo-path rewrite, or reminder rebuild integration is introduced yet.

## Boundary

Backup is an application-composition feature. It must not become a shortcut around feature repositories or storage abstractions.

```text
Feature-owned application data
        ↓
versioned feature DTO adapters
        ↓
BackupDataPort
        ↓
BackupSnapshot
        ↓
MedicationPhotoAttachmentCollector
        ↓
BackupAttachmentBundle
        ↓
Json backup.json + attachment bytes
        ↓
ZipBackupBundleArchiveCodec
        ↓
validated offline ZIP
```

Feature DTO adapters live with the owning feature so they can evolve with that domain without exposing Hive records. Backup presentation code must not read/write Hive boxes directly.

`backup.json` is the authoritative structured manifest inside the ZIP. `manifestVersion` describes the manifest/container contract while `BackupSnapshot.schemaVersion` describes the application backup schema. They remain independently versioned.

Medication photo collection deliberately converts device-local absolute `imagePath` values into deterministic archive-relative paths before encoding. Bundle decode now guarantees that each non-null medication image reference points to one safe attachment entry and that no unexpected attachment entries survive preflight.

Archive-relative paths must never be persisted as live application photo paths. The next restore slice must stage extracted bytes first, compute final local `med_photos` paths, rewrite a prepared snapshot, and expose explicit commit/rollback before the prepared snapshot is passed to `BackupDataPort.restoreAtomically()`.

## Restore safety

Restore uses replace-all semantics for the first product version because it is deterministic and explainable.

`BackupDataPort.restoreAtomically()` has a strong contract:

1. validate all incoming records before mutating current state;
2. stage file/record changes where needed;
3. either replace the complete backup-owned dataset or leave the previous state intact;
4. rebuild derived state such as reminder schedules after successful restore rather than trusting exported notification identifiers.

A partially applied restore is not acceptable.

ZIP bundle decode is a preflight boundary only. It validates archive structure and attachment completeness but does not write files or mutate repositories. This separation prevents archive parsing errors from leaving partial restore state behind.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- A future export share action hands the generated local archive to the operating-system share sheet; the user explicitly chooses the destination.
- Sensitive health data in a backup must not be logged to analytics or crash breadcrumbs.
- Encryption/password protection is a separate product/security decision and must not be implied until implemented and validated.

## Next slices

1. Add a staged photo restore port that writes attachment bytes to temporary files, reserves final `med_photos` paths, and prepares a snapshot with rewritten local paths without mutating repositories.
2. Integrate staged photo commit/rollback with `RestoreBackup` + `BackupDataPort.restoreAtomically()` so repository failure cleans staged files and file-commit failure cannot leave restored data pointing at missing photos.
3. Rebuild reminder schedules after successful restore; never restore notification IDs as authoritative data.
4. Add export/share and import/file-selection presentation only after the data + ZIP + attachment round-trip is transactionally integrated.
5. Expand coverage to extraction failure, destination conflicts, commit failure, rollback failure, and interrupted restore cleanup.
