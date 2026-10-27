# m1-read-through-chat-sessions — Chat session repository

**Status:** Not started

**Depends on:** [m1-workspace-schema-v2.md](m1-workspace-schema-v2.md)

## Out of scope

- Importing all historical JSON in one shot (M2).
- Stopping writes to `sessions/<wsId>.json` (M3).

## Goal

`IChatSessionRepository` (or split read/write ports) + SQLite adapter. `uChatSessionStore.pas`: if workspace DB has no sessions, load JSON file; on save, write SQLite. Field mapping aligned with §6.3 (`toolCallId`, `toolCalls`, etc.).

## Deliverables

- Interface(s) in `data/uRepositoryInterfaces.pas`.
- `data/sqlite/uSqliteChatSessionRepository.pas`.
- Refactor `uChatSessionStore.pas` to use repository for load/save/list/archive.

## Acceptance criteria

- [ ] Empty DB + existing session JSON → identical chat history in UI.
- [ ] New messages persist to `messages` with monotonic `seq`.
- [ ] `lastSessionId` / active session stored in `session_prefs` or coordinated with global `workspaces.last_session_id`.
- [ ] Archived sessions flag respected.

## References

- Parent §5.2, §6.3, `uChatSessionStore.pas`
