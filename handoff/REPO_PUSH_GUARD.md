# Repository push guard

Besyu tracks its Git hooks in `.githooks/` so formatting and generated localization cannot be skipped accidentally on normal local pushes.

## Install

Run once per clone:

```bash
make setup-hooks
```

`make bootstrap` also installs the hooks automatically.

The installer configures:

```bash
git config --local core.hooksPath .githooks
```

and makes `.githooks/pre-push` executable in the local clone.

## Pre-push behavior

Every `git push` then performs:

1. Snapshot the source/generated-file status.
2. Run `make pre-push-prepare`:
   - localization generation
   - `dart format lib test tool`
3. Compare the status after preparation.
4. If generation/formatting changed files, stop the push and require those changes to be reviewed and committed.
5. If no files changed, run `make check`:
   - localization validation/check
   - format check
   - Flutter analyzer
   - full test suite
6. Allow the push only when all gates pass.

The snapshot comparison means existing unrelated working-tree changes do not block a push unless the preparation step itself changes the guarded paths.

## CI remains authoritative

Git hooks are a local guard and can be bypassed with `git push --no-verify`, so GitHub CI remains required. The purpose of the hook is to catch inexpensive deterministic failures before consuming a CI run.

## Connector/remote edits

Remote repository APIs do not execute local Git hooks. Changes authored through such APIs must still satisfy CI. When a local checkout is used, `make setup-hooks` should be part of initial setup so human and automated local contributors use the same push gate.
