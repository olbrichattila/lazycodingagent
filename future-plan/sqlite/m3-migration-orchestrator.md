# m3-migration-orchestrator — Startup migration orchestrator

**Status:** Not started

**Depends on:** All M2 importers.

## Out of scope

- Default legacy flag behavior (separate doc).

## Goal

Single startup path: detect unmigrated legacy files, run importers in order, verify counts/checksums, then rename legacy files to `*.bak` with timestamp (§6.4). Record migration completion in `app_settings` (e.g. `legacy_import_done_at`).

## Deliverables

- `uStorageMigrationOrchestrator.pas` (or similar) called after `OpenGlobal`.
- User-visible log or status for long imports.
- Rollback instructions in code comments + M5 help.

## Acceptance criteria

- [ ] First launch after upgrade: legacy files renamed to `.bak`, DB populated.
- [ ] Second launch: importers skipped.
- [ ] Failure mid-import: no `.bak` rename unless verify step passed (transactional policy documented).

## References

- Parent §6.1 M3, §6.4
