# SQLite migration — implementation queue

Architecture and schema reference: [Lazarus_Embedded_Storage_and_Vector_Plan.md](../Lazarus_Embedded_Storage_and_Vector_Plan.md).

Coding rules: [`.cursor/rules/persistence-and-data-access.mdc`](../../.cursor/rules/persistence-and-data-access.mdc).

## Rule

**Always implement only the next unchecked item in the table below.**

Do not skip ahead or combine multiple items in one PR unless a document explicitly marks work as optional follow-up.

When an item ships, check it off here and move the **NEXT** marker to the following row.

**Current next item:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

---

## Implementation queue

| Done | ID | Document | Summary |
| --- | --- | --- | --- |
| [x] | m0 | [m0-foundation.md](m0-foundation.md) | Static SQLite M0 (shipped) |
| [ ] | m1a | [m1-global-schema-v2.md](m1-global-schema-v2.md) | **NEXT** — Global DB migration v2 tables |
| [ ] | m1b | [m1-workspace-schema-v2.md](m1-workspace-schema-v2.md) | Workspace DB migration v2 (chat) |
| [ ] | m1c | [m1-read-through-workspace-state.md](m1-read-through-workspace-state.md) | `uWorkspaceState` read-through + repository |
| [ ] | m1d | [m1-read-through-workspace-registry.md](m1-read-through-workspace-registry.md) | `uWorkspaceRegistry` read-through |
| [ ] | m1e | [m1-read-through-chat-sessions.md](m1-read-through-chat-sessions.md) | `uChatSessionStore` read-through |
| [ ] | m1f | [m1-read-through-syntax-schemes.md](m1-read-through-syntax-schemes.md) | `uSyntaxSchemeRegistry` read-through |
| [ ] | m1g | [m1-startup-open-global-db.md](m1-startup-open-global-db.md) | Open `global.db` at app startup |
| [ ] | m2a | [m2-importer-ini-global.md](m2-importer-ini-global.md) | One-shot INI → global DB |
| [ ] | m2b | [m2-importer-workspaces-json.md](m2-importer-workspaces-json.md) | `workspaces.json` import |
| [ ] | m2c | [m2-importer-sessions-json.md](m2-importer-sessions-json.md) | Session JSON → workspace DB |
| [ ] | m2d | [m2-importer-syntax-schemes.md](m2-importer-syntax-schemes.md) | Syntax schemes import |
| [ ] | m3a | [m3-migration-orchestrator.md](m3-migration-orchestrator.md) | Startup orchestrator + `.bak` legacy |
| [ ] | m3b | [m3-legacy-storage-flag.md](m3-legacy-storage-flag.md) | `LAZYCODINGAGENT_LEGACY_STORAGE` |
| [ ] | m3c | [m3-cutover-default-sqlite.md](m3-cutover-default-sqlite.md) | Default SQLite-only writes |
| [ ] | m4 | [m4-importer-fixtures-tests.md](m4-importer-fixtures-tests.md) | Importer fixture tests |
| [ ] | m5 | [m5-user-help-storage.md](m5-user-help-storage.md) | In-app User Guide (post-cutover) |
| [ ] | m6a | [m6-rag-schema-migration.md](m6-rag-schema-migration.md) | RAG tables + FTS5 (future) |
| [ ] | m6b | [m6-rag-hybrid-retrieval.md](m6-rag-hybrid-retrieval.md) | Hybrid retrieval Phase A |
| [ ] | m6c | [m6-remote-knowledge-brain-backends.md](m6-remote-knowledge-brain-backends.md) | Remote KB / Brain APIs |
| [ ] | m6d | [m6-sqlite-vec-phase-b.md](m6-sqlite-vec-phase-b.md) | sqlite-vec Phase B (optional) |

---

## Milestone bands

| Band | Theme |
| --- | --- |
| M0 | Static engine, migration v1, first repository, tests (done) |
| M1 | Schema v2 + read-through (legacy still works) |
| M2 | One-shot importers |
| M3 | Cutover, rollback, legacy flag |
| M4 | Automated importer tests |
| M5 | User-facing help |
| M6+ | Knowledge base / RAG (after M5) |
