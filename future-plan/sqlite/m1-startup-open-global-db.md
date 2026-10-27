# m1-startup-open-global-db — Open global DB at startup

**Status:** Not started

**Depends on:** At least one M1 read-through repository (recommend after [m1-read-through-workspace-state.md](m1-read-through-workspace-state.md) or registry).

## Out of scope

- Running M2 importers at startup.
- Creating workspace DBs for every workspace before first use (lazy open per ws is fine).

## Goal

Wire `uAppDatabase.OpenGlobal` (and migration runner) from application startup so `global.db` exists and migrates early. Repositories receive a shared connection or factory from a small app-level **database context** (no SQL in UI units).

## Deliverables

- Early init in `lazycodingagent.lpr` or `mainunit` `OnCreate` (after config root known): open global DB, run migrations.
- Document `LAZYCODINGAGENT_DATA_ROOT` / `SetConfigRootOverride` behavior unchanged.
- Shutdown: close DB cleanly on app exit.

## Acceptance criteria

- [ ] Normal app start creates or opens `global.db` under user config dir.
- [ ] Failure to open DB shows actionable error (permissions, corrupt file) without silent fallback to no-DB.
- [ ] M1 read-through repos use the opened global connection.
- [ ] No destructive migration or legacy file rename.

## References

- `uAppDatabase.pas`, `lazycodingagent.lpr`, `mainunit.pas`
