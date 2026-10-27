# m2-importer-ini-global — INI → global DB import

**Status:** Not started

**Depends on:** [m1-startup-open-global-db.md](m1-startup-open-global-db.md), M1 read-through for state (recommended complete).

## Out of scope

- Renaming INI to `.bak` (M3 orchestrator).
- API key encryption.

## Goal

Idempotent one-shot importer: read main INI (and related sections) into `llm_providers`, `saved_models`, `panel_layout`, `app_settings`. Apply §6.2 rules (LLM version upgrade, panel docked height fix).

## Deliverables

- `data/sqlite/uSqliteGlobalIniImporter.pas` (or `uMigrationImportIni.pas`).
- Callable from orchestrator (M3); safe to run when tables already populated (skip or merge policy documented).

## Acceptance criteria

- [ ] Fixture INI → row counts match provider/model/panel sections.
- [ ] Re-run importer does not duplicate providers/models.
- [ ] Docked height correction applied when importing panel rows.

## References

- Parent §6.2, `uWorkspaceState.pas`
