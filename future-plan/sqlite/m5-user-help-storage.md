# m5-user-help-storage — User Guide: storage and recovery

**Status:** Not started

**Depends on:** [m3-cutover-default-sqlite.md](m3-cutover-default-sqlite.md)

## Out of scope

- RAG / knowledge base topics (future).

## Goal

When cutover ships, update in-app User Guide per user-help rule: where `global.db` and `workspace.db` live, what happened to INI/JSON, backup tips, `LAZYCODINGAGENT_LEGACY_STORAGE`, manual recovery from `.bak`.

## Deliverables

- New or updated `help/*.md` topic(s).
- `help/index.json` keywords (`sqlite`, `database`, `backup`, `migration`).
- Optional README pointer (not duplicate of full help).

## Acceptance criteria

- [ ] Help menu shows storage topic after build (post-build copy).
- [ ] Recovery steps match orchestrator behavior.
- [ ] No promise of SQLCipher/encryption (§8).

## References

- `.cursor/rules/user-help.mdc`, parent §6.4, §8
