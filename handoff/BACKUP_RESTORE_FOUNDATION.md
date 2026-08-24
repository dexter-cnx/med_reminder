# Backup / Restore Foundation

## Status

The backup/restore work now has the application boundary, feature-owned versioned DTO adapters, a concrete Medication/DoseLog data port, deterministic JSON/ZIP codecs, photo-attachment collection + ZIP preflight, staged restore preparation, and an application-level transactional commit boundary.

Implemented:

- versioned `BackupSnapshot` / `BackupRecord` models;
- `BackupArchiveCodec` and `BackupBundleArchiveCodec` contracts;
- `BackupDataPort` with atomic replace-all semantics and compensating rollback;
- Medication and DoseLog backup DTOs with notification IDs excluded;
- deterministic `backup.json` manifest and ZIP codecs;
- `MedicationPhotoAttachmentCollector` converting local photo paths into deterministic archive-relative references;
- immutable attachment bytes with defensive-copy access;
- `ZipBackupBundleArchiveCodec` validation for safe referenced attachments, missing/unexpected entries, duplicate paths, path traversal/backslash paths, and corrupt ZIPs;
- `BackupAttachmentRestorePort` for staging imported attachment bytes outside live storage;
- staged attachment mappings that separate temporary `stagedPath` from reserved `finalPath`;
- `PrepareBackupRestore` that decodes/preflights, validates schema, stages attachments, and rewrites medication `imagePath` values only to reserved final paths;
- stage cleanup when rewrite validation fails;
- `CommitPreparedBackupRestore` transaction ordering: commit staged files first, then call `BackupDataPort.restoreAtomically()`;
- committed attachment rollback when application-data restore fails;
- explicit failure when attachment rollback itself fails;
- focused tests for decode/stage safety, final-path rewriting, file-commit failure, data-restore failure, and rollback failure;
- pinned `archive` 4.0.9 dependency.

No concrete file-backed stage/commit implementation, share sheet, file picker, or reminder rebuild integration is introduced yet.

## Boundary

```text
Feature-owned application data
        ↓
BackupDataPort / versioned DTOs
        ↓
BackupSnapshot
        ↓
MedicationPhotoAttachmentCollector
        ↓
BackupAttachmentBundle
        ↓
ZipBackupBundleArchiveCodec
        ↓
validated offline ZIP
        ↓
PrepareBackupRestore
        ↓
BackupAttachmentRestorePort.stage()
        ↓
prepared snapshot with reserved final photo paths
        ↓
BackupAttachmentRestorePort.commit()
        ↓
BackupDataPort.restoreAtomically()
        ↓
success OR attachment rollback on data failure
```

`backup.json` remains authoritative. Archive-relative attachment paths and temporary staging paths must never be persisted as live application photo paths. Prepared snapshots contain only reserved final paths.

## Restore safety

Restore uses replace-all semantics for the first product version.

The restore transaction preserves these invariants:

1. validate archive structure and application schema before mutation;
2. stage every referenced file before repository replacement;
3. reserve final photo paths during staging and rewrite snapshots only to those final paths;
4. if staging or rewrite fails, discard the stage and leave repositories untouched;
5. commit staged files before repository replacement so data never points to files that have not been promoted;
6. if file commit fails, do not mutate repositories;
7. if repository replacement fails after file commit, roll committed restore files back;
8. surface an explicit rollback failure if cleanup cannot restore file state;
9. rebuild derived reminder schedules only after the complete transaction succeeds.

A partially applied restore is not acceptable.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- Sensitive health data or attachment paths/content must not be logged to analytics or crash breadcrumbs.
- A future export share action hands the generated local archive to the OS share sheet; the user chooses the destination.
- Encryption/password protection remains a separate product/security decision.

## Next slices

1. Add a concrete file-backed `BackupAttachmentRestorePort` using temporary staging directories and collision-safe reserved `med_photos` destinations.
2. Add interrupted-stage cleanup and verify commit/rollback behavior against real temporary files.
3. Rebuild reminder schedules only after the complete restore transaction succeeds.
4. Add export/share and import/file-selection presentation after transactional round-trip coverage is green.
5. Expand coverage to destination conflicts, filesystem commit failure, filesystem rollback failure, and stale-stage cleanup.
