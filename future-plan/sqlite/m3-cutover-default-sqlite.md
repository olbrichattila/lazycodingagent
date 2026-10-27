# m3-cutover-default-sqlite — SQLite-only default backend

**Status:** Not started

**Depends on:** [m3-migration-orchestrator.md](m3-migration-orchestrator.md), [m3-legacy-storage-flag.md](m3-legacy-storage-flag.md)

## Out of scope

- RAG tables (M6).

## Goal

Default path: repositories write **only** SQLite. Stop creating/updating legacy INI, `workspaces.json`, session JSON, syntax files (parent §9 item 5). JSON session files not used at runtime after cutover.

## Deliverables

- Remove dual-write to legacy from M1 read-through paths.
- Ensure new installs never create legacy files.

## Acceptance criteria

- [ ] Fresh install: only `global.db` + `workspace.db` under config.
- [ ] Existing migrated users: no writes to `.bak` originals.
- [ ] Legacy flag still works for support.

## References

- Parent §9, M1 read-through units
