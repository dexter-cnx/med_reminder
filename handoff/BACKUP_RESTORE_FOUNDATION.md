# Backup / Restore Foundation

## Status

The backup/restore work now has the application boundary, feature-owned versioned DTO adapters, a concrete Medication/DoseLog data port, deterministic JSON/ZIP codecs, photo-attachment collection + ZIP preflight, staged restore preparation, transactional commit/rollback coordination, and a concrete file-backed attachment restore port.

Implemented:

- versioned `BackupSnapshot` / `BackupRecord` models;
- `BackupArchiveCodec` and `BackupBundleArchiveCodec` contracts;
- `BackupDataPort` with atomic replace-all semantics and compensating rollback;
- Medication and DoseLog backup DTOs with notification IDs excluded;
- deterministic `backup.json` manifest and ZIP codecs;
- `MedicationPhotoAttachmentCollector` converting local photo paths into deterministic archive-relative references;
- immutable attachment bytes with defensive-copy access;
- `ZipBackupBundleArchiveCodec` validation for safe referenced attachments, missing/unexpected entries, duplicate paths, path traversal/backslash paths, and corrupt ZIPs;
- `BackupAttachmentRestorePort` with stage / commit / rollback / discard semantics;
- staged attachment mappings that separate temporary `stagedPath` from reserved `finalPath`;
- `PrepareBackupRestore` that decodes/preflights, validates schema, stages attachments, and rewrites medication `imagePath` values only to reserved final paths;
- `CommitPreparedBackupRestore` transaction ordering: commit staged files first, then call `BackupDataPort.restoreAtomically()`;
- committed attachment rollback on ordinary application-data restore failure;
- committed photos are deliberately preserved when the data port reports `backup_restore_rollback_failed`, because surviving records may still reference the new final paths;
- `FileBackupAttachmentRestorePort` using isolated temporary stage directories and collision-safe final `med_photos` destinations;
- file-backed commit preflight before promotion, rollback/discard behavior, and persistent stage metadata;
- stage metadata path validation so corrupted metadata cannot move/delete files outside the stage root or managed `med_photos` directory;
- stale-stage cleanup that removes expired staging directories only and never prunes live medication photos;
- focused in-memory and real-temporary-file tests for stage, commit, rollback, discard, metadata path safety, and stale cleanup;
- pinned `archive` 4.0.9 dependency.

No share sheet, file picker, restore-flow DI wiring, or reminder rebuild integration is introduced yet.

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
FileBackupAttachmentRestorePort.stage()
        ↓
prepared snapshot with reserved final photo paths
        ↓
FileBackupAttachmentRestorePort.commit()
        ↓
BackupDataPort.restoreAtomically()
        ↓
success OR safe attachment rollback/preservation policy
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
7. if repository replacement fails after file commit and repository rollback is complete, remove committed restore files;
8. if repository rollback itself fails, preserve committed restore photos because partially restored records may still reference them;
9. constrain persisted stage metadata paths to the managed staging root and `med_photos` root;
10. clean interrupted stale stages without touching live medication photos;
11. rebuild derived reminder schedules only after the complete transaction succeeds.

A partially applied restore is not acceptable. When complete consistency cannot be automatically re-established, preserving potentially referenced files is safer than creating known dangling photo paths.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- Sensitive health data or attachment paths/content must not be logged to analytics or crash breadcrumbs.
- A future export share action hands the generated local archive to the OS share sheet; the user chooses the destination.
- Encryption/password protection remains a separate product/security decision.

## Next slices

1. Wire the file-backed restore port and prepare/commit use cases through Riverpod DI without exposing filesystem details to presentation.
2. Add a single restore coordinator for decode → stage → commit → data restore and run stale-stage cleanup at an appropriate app lifecycle boundary.
3. Rebuild reminder schedules only after the complete restore transaction succeeds; notification IDs remain derived state.
4. Add export/share and import/file-selection presentation after the transactional round-trip is wired end-to-end.
5. Expand integration coverage for destination conflicts, interrupted restores, and reminder rebuild failure policy.
