# m2-importer-sessions-json — Session JSON → workspace DB

**Status:** Not started

**Depends on:** [m1-workspace-schema-v2.md](m1-workspace-schema-v2.md), [m2-importer-workspaces-json.md](m2-importer-workspaces-json.md)

## Out of scope

- Global `last_session_id` sync edge cases beyond §6.3.

## Goal

For each workspace, import `sessions/<wsId>.json` into that workspace’s `workspace.db` using §6.3 field mapping.

## Deliverables

- Per-workspace importer reusing `uChatSessionStore` JSON parsing where possible.
- Progress/logging for large histories.

## Acceptance criteria

- [ ] Fixture JSON → session count and message count match.
- [ ] Sample message fields (`tool_calls_json`, `visual_summary`) round-trip.
- [ ] `session_prefs` receives `lastSessionId` when present in JSON root.

## References

- Parent §6.3, `uChatSessionStore.pas`
