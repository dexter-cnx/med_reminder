# Backup / Restore Foundation

## Status

The first backup/restore slice establishes the application boundary for a future fully offline ZIP export/import flow.

Implemented in this slice:

- versioned `BackupSnapshot` model;
- namespace-based `BackupRecord` model so Backup does not import feature persistence implementations;
- `BackupArchiveCodec` contract for archive serialization/deserialization;
- `BackupDataPort` contract for capturing application-owned data and restoring it atomically;
- `CreateBackup` and `RestoreBackup` use cases;
- schema validation before restore mutation;
- focused tests for capture/encode, corrupt archive failure, unsupported schema rejection, and atomic restore delegation.

No ZIP package, share sheet, file picker, Hive adapter, or photo copying is introduced in this foundation slice.

## Boundary

Backup is an application-composition feature. It must not become a shortcut around feature repositories or storage abstractions.

```text
Feature-owned application data
        ↓
BackupDataPort
        ↓
BackupSnapshot
        ↓
BackupArchiveCodec
        ↓
Versioned offline archive
```

The concrete data-port implementation may compose Medication, DoseLog, Refill, Check-in, Appointment, Emergency, Settings, and future feature APIs, but Backup presentation code must not read/write Hive boxes directly.

`BackupRecord.namespace` identifies the owning feature/data contract. The record payload is deliberately storage-neutral; a future adapter is responsible for versioned conversion to and from feature-owned import/export DTOs.

## Restore safety

Restore uses replace-all semantics for the first product version because it is deterministic and explainable.

`BackupDataPort.restoreAtomically()` has a strong contract:

1. validate all incoming records before mutating current state;
2. stage file/record changes where needed;
3. either replace the complete backup-owned dataset or leave the previous state intact;
4. rebuild derived state such as reminder schedules after successful restore rather than trusting exported notification identifiers.

A partially applied restore is not acceptable.

`RestoreBackup` rejects a snapshot whose schema version is not the currently supported version before calling the data port.

## Privacy

- Backup remains offline-first.
- No archive is uploaded by Besyu.
- A future export share action hands the generated local archive to the operating-system share sheet; the user explicitly chooses the destination.
- Sensitive health data in a backup must not be logged to analytics or crash breadcrumbs.
- Encryption/password protection is a separate product/security decision and must not be implied until implemented and validated.

## Next slices

1. Define versioned feature export/import DTO adapters for Medication and DoseLog first.
2. Implement a concrete application `BackupDataPort` with preflight validation and rollback-safe replace-all behavior.
3. Add the archive codec and versioned `backup.json` manifest, then ZIP attachment/photo handling.
4. Rebuild reminder schedules after successful restore; never restore notification IDs as authoritative data.
5. Add export/share and import/file-selection presentation only after the data and archive round-trip is tested.
6. Expand coverage to corrupt archives, unsupported future schemas, photo path rewriting, and restore failure rollback.
