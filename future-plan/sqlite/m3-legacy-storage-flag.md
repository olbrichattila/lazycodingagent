# m3-legacy-storage-flag — LAZYCODINGAGENT_LEGACY_STORAGE

**Status:** Not started

**Depends on:** [m3-migration-orchestrator.md](m3-migration-orchestrator.md)

## Out of scope

- UI toggle for legacy mode (support-only env var is enough for v1).

## Goal

When **`LAZYCODINGAGENT_LEGACY_STORAGE=1`**, all repositories read/write INI/JSON only; SQLite optional or read-only. Document recovery: restore `.bak` files, remove `.db`, set flag, restart.

## Deliverables

- Central check in database context factory or repository wiring.
- README / CONTRIBUTING note; M5 help cross-link.

## Acceptance criteria

- [ ] Flag forces legacy paths even if `global.db` exists.
- [ ] Flag documented in parent plan §6.4 and user help (M5).
- [ ] No orchestrator run when flag set (or explicit skip).

## References

- Parent §6.4, `.cursor/rules/persistence-and-data-access.mdc`
