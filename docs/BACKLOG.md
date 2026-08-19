# Backlog

## PR #2 — Native companion features

Scope remains the native handoff described in `handoff/NATIVE_HANDOFF.md`: iOS Live Activity / Dynamic Island, watchOS, Android ongoing notification fallback, Wear OS, and real-device evidence.

PR #2 must reference the post-merge bootstrap baseline tag `v0.1.0-bootstrap-fixed`.

## PR #3 — Offline backup / restore

Goal: reduce device-loss and device-migration risk without introducing a backend or cloud account.

### Export

- Export medication records, dose logs, app-owned medication photos, and backup metadata into a versioned ZIP archive.
- Do not export scheduled notification IDs as authoritative state; reminders must be rebuilt after import.
- Include a manifest such as `backup.json` with at least:
  - schema version
  - app version
  - exported-at timestamp
  - locale/timezone metadata when useful for diagnostics
  - record/photo inventory and integrity information
- Write the archive to a temporary/app-controlled location and expose it through the platform share sheet.
- Keep the feature entirely offline. Sharing to Drive/iCloud/etc. is the user's explicit destination choice through the OS share sheet, not an application server.

### Import

- Validate archive/schema before mutating current data.
- Reject unsupported future schema versions with a clear error.
- Import through repository/application contracts rather than writing Hive boxes from presentation code.
- Restore photos into the app-owned photo directory and rewrite paths as needed.
- Rebuild reminders from imported `Medication` + `DoseLog` domain state in the current timezone.
- Run orphan-photo pruning after a successful import.
- Define duplicate/conflict behavior explicitly before implementation (replace-all is the recommended first version because it is deterministic and easy to explain).

### Tests / acceptance

- export -> import round trip preserves medications and dose logs
- photos survive the round trip and point to valid app-owned paths
- invalid/corrupt ZIP does not partially mutate existing data
- unsupported schema is rejected
- import does not resurrect expired or `untilEmpty` medications with zero remaining stock
- notification IDs are regenerated, not trusted from the archive

## Release baseline after PR #1

Only after PR #1 is merged and required CI is green, create the bootstrap baseline tag from `main`:

```bash
git checkout main
git pull --ff-only
git tag v0.1.0-bootstrap-fixed
git push origin v0.1.0-bootstrap-fixed
```

Do not create this tag from the feature branch or before PR #1 is merged.
