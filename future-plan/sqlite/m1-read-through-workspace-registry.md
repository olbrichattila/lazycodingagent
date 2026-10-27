# m1-read-through-workspace-registry — Workspace registry (SQLite)

**Status:** Done

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Goal

`IWorkspaceRegistryRepository` + SQLite adapter. `uWorkspaceRegistry.pas` loads and saves via `workspaces` table in `global.db`.

## Delivered

- `data/sqlite/uSqliteWorkspaceRegistryRepository.pas`
- `uWorkspaceRegistry.pas` — `Load` / `Save` → `LoadFromGlobalDb` / `SaveToGlobalDb`

**Note:** `MigrateFromLegacyIni` seeds a first workspace from in-memory workspace name/root when the registry is empty (not an INI file import). `WorkspaceRegistryFileName` remains as a legacy path constant only if still referenced; runtime does not read `workspaces.json`.

## Acceptance criteria

- [x] Add/rename/remove workspace updates `workspaces` table.
- [x] `folder_path` UNIQUE constraint enforced via SQLite.
- [x] Active workspace id persisted with registry rows.

## References

- Parent §5.1 `workspaces`, `uWorkspaceRegistry.pas`
