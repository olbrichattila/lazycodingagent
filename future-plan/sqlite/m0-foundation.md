# m0-foundation — Static SQLite engine (done)

**Status:** Done (shipped ~v0.1.31)

**Depends on:** —

## Summary

Land statically linked SQLite, connection/migration runner, first repository port, and CI/release build hooks. Production app still uses INI/JSON for all user settings; no `global.db` created on normal startup until M1g.

## Delivered

| Area | Location |
| --- | --- |
| Amalgamation + FTS5 build flags | `third_party/sqlite/` |
| Static link package | `packages/LazySqliteStatic/`, `uSqlite3Embed.pas`, `sqlite3_embed.o` via build scripts |
| DB layer | `uAppDatabase.pas` — `global.db`, `workspaces/<wsId>/workspace.db`, migration **v1** (`schema_migrations`, `app_settings`) |
| Repository | `data/uRepositoryInterfaces.pas`, `data/sqlite/uSqliteAppSettingsRepository.pas` |
| Test | `tests/test_app_database.*` |
| Build | `scripts/install-lazarus-sqlite.*`, `build-sqlite-static.*`, PR + release CI |
| Rules | `.cursor/rules/persistence-and-data-access.mdc` |

## Acceptance criteria (met)

- [x] Binary links SQLite without system `libsqlite3` on Linux (`ldd` clean).
- [x] Console test round-trips settings via `IAppSettingsRepository` on global and workspace DBs.
- [x] Main app links `uSqlite3Embed`; no startup DB I/O in M0.

## References

- Parent plan: [Lazarus_Embedded_Storage_and_Vector_Plan.md](../Lazarus_Embedded_Storage_and_Vector_Plan.md) — M0 status table
