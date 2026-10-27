# m2-importer-workspaces-json — workspaces.json import

**Status:** Not started

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Out of scope

- Session import (next item).

## Goal

Import `workspaces.json` into `workspaces` table (id, display_name, folder_path, last_session_id, sort_order).

## Deliverables

- Importer unit invoked from M3 orchestrator.
- Idempotent: match by `id` or `folder_path`.

## Acceptance criteria

- [ ] Sample `workspaces.json` fixture → N rows in `workspaces`.
- [ ] `sort_order` preserved.
- [ ] Second run is no-op or updates changed fields only.

## References

- `uWorkspaceRegistry.pas`, parent §5.1
