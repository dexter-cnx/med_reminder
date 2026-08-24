# Backup / Restore Foundation

## Status

The backup/restore work now has both the application boundary and the first feature-owned versioned DTO adapters required for a future fully offline ZIP export/import flow.

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
- focused tests for capture/encode, corrupt archive failure, unsupported schemas, atomic restore delegation, DTO round trips, and notification-ID omission.

No ZIP package, share sheet, file picker, concrete application data port, or photo copying is introduced yet.

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
Versioned offline archive
```

Feature DTO adapters live with the owning feature so they can evolve with that domain without exposing Hive records. The future concrete `BackupDataPort` composes those adapters into namespace-based `BackupRecord` values.

Backup presentation code must not read/write Hive boxes directly.

## Restore safety

Restore uses replace-all semantics for the first product version because it is deterministic and explainable.

`BackupDataPort.restoreAtomically()` has a strong contract:

1. validate all incoming records before mutating current state;
2. stage file/record changes where needed;
3. either replace the complete backup-owned dataset or leave the previous state intact;
4. rebuild derived state such as reminder schedules after successful restore rather than trusting exported notification identifiers.

A partially applied restore is not acceptable.

`RestoreBackup` rejects a snapshot whose schema version is not the currently supported version before calling the data port. Feature-level DTO decoders also reject unsupported record versions.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- A future export share action hands the generated local archive to the operating-system share sheet; the user explicitly chooses the destination.
- Sensitive health data in a backup must not be logged to analytics or crash breadcrumbs.
- Encryption/password protection is a separate product/security decision and must not be implied until implemented and validated.

## Next slices

1. Implement a concrete application `BackupDataPort` for Medication and DoseLog using repository contracts, with full preflight validation before mutation.
2. Add rollback-safe replace-all behavior and tests proving failed restore leaves current data intact.
3. Add the archive codec and versioned `backup.json` manifest, then ZIP attachment/photo handling.
4. Rebuild reminder schedules after successful restore; never restore notification IDs as authoritative data.
5. Add export/share and import/file-selection presentation only after the data and archive round-trip is tested.
6. Expand coverage to corrupt archives, unsupported future schemas, photo path rewriting, and restore failure rollback.
