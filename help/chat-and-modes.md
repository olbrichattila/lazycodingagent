# Chat, sessions, and modes

## Multiple sessions

Each workspace can run **several chat sessions** in parallel:

- Every session has its own conversation and **agent engine**.
- Switching sessions or workspaces does **not** stop a run in another session; it continues in the background.
- Switch sessions from **Sessions** in the nav rail; the active session name appears on the **Chat** tab.

Create sessions from **Sessions** (**+ New Chat Session**). Archive, restore, or delete from the same view (archiving is not a permanent delete until you delete from the archive list).

## Composer modes

| Mode | Purpose |
|------|---------|
| **Ask** | Q&A and exploration. Read-only tools (files, search, git inspect). No writes or shell. |
| **Plan** | Design and specs. Can save plan markdown under `.plan/`. No arbitrary file writes or shell. |
| **Agent** | Full coding autopilot: patches, writes, shell, builds. Default for implementation work. |

The mode applies to the **next run** and is sent with the system prompt so the model knows which tools exist.

Pick **Ask**, **Plan**, or **Agent** from the **mode** combo at the left of the composer footer.

## Model selection

The **model** combo lists models you configured in Settings. The choice is kept with the workspace and shown on the status bar when relevant.

## Debugging mode

In **Settings → Agent Behavior**, enable **Debugging mode** to show **full tool results** in the chat transcript. When disabled, successful tool calls are hidden in chat; **errors** still appear.

For a step-by-step trace of LLM requests and tool calls, use execution / utility views when available in your build.

## Cancel and exit

Use **Stop** / cancel in the chat UI to abort an active run. Quitting the app with runs in progress should prompt to stop them cleanly.
