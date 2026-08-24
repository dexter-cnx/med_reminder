# Backup / Restore Foundation

## Status

The backup/restore work now has the application boundary, feature-owned versioned DTO adapters, a concrete Medication/DoseLog data port, focused restore-safety coverage, and a versioned JSON manifest codec for the future fully offline ZIP export/import flow.

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
- focused `MedicationBackupDataPort` tests for valid capture, orphan filtering, preflight rejection before mutation, successful replace-all, first-repository rollback, and second-repository rollback;
- `JsonBackupArchiveCodec` for deterministic UTF-8 `backup.json` manifest bytes;
- independent manifest versioning so archive-container evolution is not coupled to the application backup schema;
- manifest round-trip, malformed-manifest, invalid-record, and unsupported-manifest-version tests;
- focused tests for capture/encode, corrupt archive failure, unsupported schemas, atomic restore delegation, DTO round trips, and notification-ID omission.

No ZIP package, share sheet, file picker, ZIP attachment/photo copying, or reminder rebuild integration is introduced yet.

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
BackupArchiveCodec
        ↓
versioned backup.json manifest
        ↓
future ZIP container + attachments/photos
```

Feature DTO adapters live with the owning feature so they can evolve with that domain without exposing Hive records. The concrete Medication/DoseLog data port composes repository contracts and DTO adapters into namespace-based `BackupRecord` values; it does not access Hive records directly.

`backup.json` is the authoritative structured manifest inside the future archive. `manifestVersion` describes the manifest/container contract while `BackupSnapshot.schemaVersion` describes the application backup schema. They must remain independently versioned.

Backup presentation code must not read/write Hive boxes directly.

## Restore safety

Restore uses replace-all semantics for the first product version because it is deterministic and explainable.

`BackupDataPort.restoreAtomically()` has a strong contract:

1. validate all incoming records before mutating current state;
2. stage file/record changes where needed;
3. either replace the complete backup-owned dataset or leave the previous state intact;
4. rebuild derived state such as reminder schedules after successful restore rather than trusting exported notification identifiers.

A partially applied restore is not acceptable.

`RestoreBackup` rejects a snapshot whose schema version is not the currently supported version before calling the data port. Feature-level DTO decoders also reject unsupported record versions. The JSON manifest codec rejects malformed structure and unsupported manifest versions before a snapshot can reach restore mutation. The Medication/DoseLog port snapshots current repository state before replacement and attempts compensating rollback whenever a repository replacement fails after mutation may have begun.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- A future export share action hands the generated local archive to the operating-system share sheet; the user explicitly chooses the destination.
- Sensitive health data in a backup must not be logged to analytics or crash breadcrumbs.
- Encryption/password protection is a separate product/security decision and must not be implied until implemented and validated.

## Next slices

1. Add the ZIP container around `backup.json`, then attachment/photo collection and deterministic archive paths.
2. Rewrite restored photo paths only after archive extraction is staged and validated.
3. Rebuild reminder schedules after successful restore; never restore notification IDs as authoritative data.
4. Add export/share and import/file-selection presentation only after the data + ZIP + attachment round-trip is tested.
5. Expand coverage to corrupt ZIPs, missing manifests, duplicate archive paths, photo path rewriting, and extraction/restore rollback.
