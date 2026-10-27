# m1-read-through-workspace-state — Workspace state repository

**Status:** Not started

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Out of scope

- Full INI import on first launch (M2); read-through may **load** existing INI when DB tables are empty.
- Cutover / stop writing INI (M3).

## Goal

Introduce `IWorkspaceStateRepository` + SQLite adapter. `uWorkspaceState.pas` delegates load/save: if SQLite has no rows for providers/panels/settings, load legacy INI; on **Save**, persist to SQLite (dual-write to INI optional in M1 — prefer SQLite write + keep INI read until M3).

## Deliverables

- `data/uRepositoryInterfaces.pas` — interface for workspace-global state (providers, models, panel layout, app prefs mapped to tables).
- `data/sqlite/uSqliteWorkspaceStateRepository.pas` (or split by concern if too large).
- Refactor `uWorkspaceState.pas` to use repository when DB available; preserve **`LLM_CONFIG_VERSION`** upgrade behavior (parent §6.2).
- Panel **docked height** correction (§6.2) applied on load path (INI or DB).

## Acceptance criteria

- [ ] Existing users: unchanged behavior when `global.db` empty (INI only).
- [ ] After save with DB open: corresponding rows in `llm_providers`, `saved_models`, `panel_layout`, and/or `app_settings`.
- [ ] `LLM_CONFIG_VERSION` migration from v1/v2 INI still runs once.
- [ ] No SQL types leak above repository layer (persistence rule).

## References

- Parent §6.2, `uWorkspaceState.pas`
