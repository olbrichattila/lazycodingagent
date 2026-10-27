# m4-importer-fixtures-tests — Importer fixture tests

**Status:** Not started

**Depends on:** M2 importers (and preferably M3 orchestrator).

## Out of scope

- Full UI integration tests.

## Goal

`tests/fixtures/sqlite-migration/` with representative INI, `workspaces.json`, session JSON, syntax files. Console or FPC test project runs importers in temp dir and asserts row counts and sample fields (parent §6.1 M4).

## Deliverables

- Fixture tree under `tests/fixtures/sqlite-migration/`.
- `tests/test_sqlite_migration.lpr` (or extend `test_app_database`) + CI job step on Linux.

## Acceptance criteria

- [ ] CI runs migration tests on PR.
- [ ] At least one assertion per importer type.
- [ ] Tests use `SetConfigRootOverride` / temp dir; no writes to user home.

## References

- Parent §6.1 M4, M2 docs
