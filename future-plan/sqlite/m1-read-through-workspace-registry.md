# m1-read-through-workspace-registry — Workspace registry repository

**Status:** Not started

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Out of scope

- Bulk import of `workspaces.json` (M2).
- Removing JSON file (M3).

## Goal

`IWorkspaceRegistryRepository` + SQLite adapter. `uWorkspaceRegistry.pas`: if `workspaces` table empty, load `workspaces.json`; on mutations, write SQLite. Respect existing **`MigrateFromLegacyIni`** path.

## Deliverables

- Interface + `uSqliteWorkspaceRegistryRepository.pas`.
- Integration in `uWorkspaceRegistry.pas` (list, add, remove, reorder, active workspace id).

## Acceptance criteria

- [ ] Empty DB + existing `workspaces.json` → same UI as today.
- [ ] Add/rename/remove workspace updates `workspaces` table.
- [ ] `folder_path` UNIQUE constraint enforced; errors surfaced like JSON path today.
- [ ] Legacy INI migration hook still runs when applicable.

## References

- Parent §5.1 `workspaces`, `uWorkspaceRegistry.pas`
