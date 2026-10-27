# m1-workspace-schema-v2 — Workspace DB migration v2

**Status:** Not started

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Out of scope

- Chat store read-through (separate item).
- Session JSON import (M2).

## Goal

Add migration **version 2** on per-workspace `workspace.db` for chat persistence tables §5.2.

## Deliverables

- Migration v2 SQL: `sessions`, `messages`, `session_prefs` (with `ON DELETE CASCADE` on messages).
- Test: create workspace DB under temp dir, migrate to v2, optional smoke insert/select.

## Acceptance criteria

- [ ] `OpenWorkspace(wsId)` applies v2 when global path layout already exists from M0.
- [ ] Schema version row shows **2** after migrate.
- [ ] Tables match §5.2; composite PK on `(session_id, seq)` for messages.

## References

- Parent plan §5.2
- `uAppDatabase.pas`, `uChatSessionStore.pas` (field names for later mapping)
