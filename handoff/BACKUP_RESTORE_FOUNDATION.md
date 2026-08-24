# Backup / Restore Foundation

## Status

The backup/restore work now has the application boundary, feature-owned versioned DTO adapters, a concrete Medication/DoseLog data port, focused restore-safety coverage, a versioned JSON manifest codec, deterministic ZIP containers, photo-attachment collection + ZIP bundle preflight, and a staged restore preparation boundary for the fully offline export/import flow.

Implemented:

- versioned `BackupSnapshot` / `BackupRecord` models;
- `BackupArchiveCodec` and `BackupBundleArchiveCodec` contracts;
- `BackupDataPort` with atomic replace-all semantics and compensating rollback;
- Medication and DoseLog backup DTOs with notification IDs excluded;
- deterministic `backup.json` manifest and ZIP codecs;
- `MedicationPhotoAttachmentCollector` converting local photo paths into deterministic archive-relative references;
- immutable attachment bytes with defensive-copy access;
- `ZipBackupBundleArchiveCodec` that validates safe referenced attachments, missing/unexpected entries, duplicate paths, path traversal/backslash paths, and corrupt ZIPs;
- `BackupAttachmentRestorePort` as the boundary for staging imported attachment bytes outside live application storage;
- `PrepareBackupRestore` two-phase preparation that decodes/preflights the ZIP, validates schema, stages attachments, rewrites medication `imagePath` values to staged local paths, and discards the stage if rewrite validation fails;
- focused tests proving decode failure does not stage files and incomplete staged mappings are discarded before failure;
- pinned `archive` 4.0.9 dependency.

No share sheet, file picker, live attachment commit, repository-integrated staged rollback, or reminder rebuild integration is introduced yet.

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
prepared snapshot with staged local photo paths
        ↓
future transactional commit + BackupDataPort.restoreAtomically()
```

`backup.json` remains authoritative. Archive-relative attachment paths must never be persisted as live application photo paths. Preparation now separates archive parsing and file staging from repository mutation so failures before commit cannot partially replace application data.

## Restore safety

Restore uses replace-all semantics for the first product version.

The restore transaction must preserve these invariants:

1. validate archive structure and application schema before mutation;
2. stage every referenced file before repository replacement;
3. rewrite photo paths only from verified stage mappings;
4. if staging or rewrite fails, discard the stage and leave repositories untouched;
5. when commit integration is added, either both file commit and repository replacement succeed or cleanup/rollback restores the pre-import state;
6. rebuild derived reminder schedules after successful restore rather than trusting exported notification identifiers.

A partially applied restore is not acceptable.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- Sensitive health data or attachment paths/content must not be logged to analytics or crash breadcrumbs.
- A future export share action hands the generated local archive to the OS share sheet; the user chooses the destination.
- Encryption/password protection remains a separate product/security decision.

## Next slices

1. Add a concrete file-backed staged photo restore implementation using temporary storage and reserved final `med_photos` destinations.
2. Add explicit stage commit/discard semantics and integrate them with `BackupDataPort.restoreAtomically()` so repository or file-commit failure cannot leave dangling photo paths.
3. Rebuild reminder schedules only after the complete restore transaction succeeds.
4. Add export/share and import/file-selection presentation after transactional round-trip coverage is green.
5. Expand coverage to extraction failure, destination conflicts, commit failure, rollback failure, and interrupted-stage cleanup.
