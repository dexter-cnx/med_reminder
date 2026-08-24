# Backup / Restore Foundation

## Status

The backup/restore work now has the application boundary, feature-owned versioned DTO adapters, a concrete Medication/DoseLog data port, focused restore-safety coverage, a versioned JSON manifest codec, a deterministic ZIP container, and a photo-attachment collection boundary for the fully offline export/import flow.

Implemented:

- versioned `BackupSnapshot` model;
- namespace-based `BackupRecord` model so Backup does not import feature persistence implementations;
- deeply immutable backup record payloads;
- `BackupArchiveCodec` contract for archive serialization/deserialization;
- `BackupDataPort` contract for capturing application-owned data and restoring it atomically;
- `CreateBackup` and `RestoreBackup` use cases;
- schema validation before restore mutation;
- versioned Medication backup DTO conversion;
- versioned DoseLog backup DTO conversion;
- Medication backup deliberately excludes notification IDs because notification schedules are derived state;
- concrete `MedicationBackupDataPort` composed only from Medication and DoseLog repository contracts;
- full restore preflight for DTO validity, duplicate IDs, namespace support, record/payload ID agreement, and DoseLog-to-Medication references;
- compensating rollback when either repository replacement reports failure after mutation begins;
- capture filtering so orphan DoseLogs are not exported after their Medication has been deleted;
- focused `MedicationBackupDataPort` restore-safety tests;
- `JsonBackupArchiveCodec` for deterministic UTF-8 `backup.json` manifest bytes;
- independent manifest versioning so archive-container evolution is not coupled to the application backup schema;
- `ZipBackupArchiveCodec` wrapping the authoritative `backup.json` manifest in a deterministic ZIP container;
- ZIP validation for corrupt bytes, missing manifests, and duplicate archive paths before manifest decoding;
- pinned `archive` 4.0.9 dependency;
- `BackupAttachmentSource` boundary so attachment collection does not depend on `PhotoService`, Hive, or presentation code;
- `FileBackupAttachmentSource` local-file implementation;
- `MedicationPhotoAttachmentCollector` that reads referenced medication photos, creates deterministic `attachments/medication/<encoded-medication-id>.<ext>` paths, and returns an archive-ready snapshot with portable image references;
- attachment collection tests for path rewriting, no-photo records, and read failures.

No share sheet, file picker, attachment ZIP insertion, staged attachment extraction, restored local photo-path rewriting, or reminder rebuild integration is introduced yet.

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
archive-ready snapshot + BackupAttachment bytes
        ↓
JsonBackupArchiveCodec / backup.json
        ↓
ZipBackupArchiveCodec
        ↓
ZIP container
```

Feature DTO adapters live with the owning feature so they can evolve with that domain without exposing Hive records. The concrete Medication/DoseLog data port composes repository contracts and DTO adapters into namespace-based `BackupRecord` values; it does not access Hive records directly.

`backup.json` is the authoritative structured manifest inside the ZIP. `manifestVersion` describes the manifest/container contract while `BackupSnapshot.schemaVersion` describes the application backup schema. They remain independently versioned.

Medication photo collection deliberately converts device-local absolute `imagePath` values into deterministic archive-relative paths before the snapshot is encoded. These archive-relative paths must never be persisted as live application photo paths. Restore must first stage and validate attachment extraction, then rewrite them to new local `med_photos` paths before data replacement.

Backup presentation code must not read/write Hive boxes directly.

## Restore safety

Restore uses replace-all semantics for the first product version because it is deterministic and explainable.

`BackupDataPort.restoreAtomically()` has a strong contract:

1. validate all incoming records before mutating current state;
2. stage file/record changes where needed;
3. either replace the complete backup-owned dataset or leave the previous state intact;
4. rebuild derived state such as reminder schedules after successful restore rather than trusting exported notification identifiers.

A partially applied restore is not acceptable.

`RestoreBackup` rejects a snapshot whose schema version is not the currently supported version before calling the data port. Feature-level DTO decoders reject unsupported record versions. The ZIP codec rejects corrupt archives, missing manifests, and duplicate archive paths; the JSON manifest codec then rejects malformed structure and unsupported manifest versions before a snapshot can reach restore mutation. The Medication/DoseLog port snapshots current repository state before replacement and attempts compensating rollback whenever a repository replacement fails after mutation may have begun.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- A future export share action hands the generated local archive to the operating-system share sheet; the user explicitly chooses the destination.
- Sensitive health data in a backup must not be logged to analytics or crash breadcrumbs.
- Encryption/password protection is a separate product/security decision and must not be implied until implemented and validated.

## Next slices

1. Insert collected attachments into the ZIP and validate that every manifest photo reference has exactly one safe archive entry.
2. Stage and validate ZIP attachment extraction, then rewrite restored photo paths only after extraction succeeds.
3. Rebuild reminder schedules after successful restore; never restore notification IDs as authoritative data.
4. Add export/share and import/file-selection presentation only after the data + ZIP + attachment round-trip is tested.
5. Expand coverage to missing attachments, unsafe archive paths, photo path rewriting, and extraction/restore rollback.
