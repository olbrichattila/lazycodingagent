# m1-global-schema-v2 — Global DB migration v2

**Status:** Not started

**Depends on:** [m0-foundation.md](m0-foundation.md)

## Out of scope

- Wiring stores to SQLite (later M1 read-through items).
- One-shot INI import (M2).
- Renaming or deleting legacy INI files (M3).

## Goal

Add migration **version 2** on `global.db` creating normalized tables from parent plan §5.1. Existing v1 (`app_settings`, `schema_migrations`) remains; v2 adds tables only.

## Deliverables

- `uAppDatabase.pas` (or dedicated migration unit): `ApplyMigration2Global` with SQL for:
  - `workspaces`
  - `llm_providers`
  - `saved_models`
  - `syntax_schemes`
  - `panel_layout`
- Extend use of `app_settings` for typed keys as needed (no cutover of readers yet).
- Unit test or extend `test_app_database` to open fresh DB and assert migration version **2** and table existence.

## Acceptance criteria

- [ ] Fresh `global.db` reaches schema version 2 after open/migrate.
- [ ] Upgrading from v1-only DB applies v2 without data loss on `app_settings`.
- [ ] SQL matches §5.1 column names and constraints (FK on `saved_models`).
- [ ] No change to production INI read/write paths.

## References

- [Lazarus_Embedded_Storage_and_Vector_Plan.md](../Lazarus_Embedded_Storage_and_Vector_Plan.md) §5.1
- `uAppDatabase.pas`
