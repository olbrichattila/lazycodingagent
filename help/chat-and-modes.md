# Chat, sessions, and modes

## Multiple sessions

Each workspace can run **several chat sessions** in parallel:

- Every session has its own conversation and **agent engine**.
- Switching sessions or workspaces does **not** stop a run in another session; it continues in the background.
- Switch sessions from the **tab strip inside the Chat page** (one tab per active chat) or from **Sessions** in the nav rail; the active session name also appears in the **Session:** label on the Chat page.

Create sessions from **Sessions** (**+ New Chat Session**) or click **+** on the **session tab strip** at the top of the Chat page (same action). **✕** on a session tab archives that chat (restore from **Sessions**). Archive, restore, or permanently delete from the **Sessions** nav view (archiving is not a permanent delete until you delete from the archive list).

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

## Debugging mode vs live trace

In **Settings → Agent Behavior**, enable **Debugging mode** to show **full tool results** in the chat transcript. When disabled, successful tool JSON stays out of chat; **errors** still appear.

With debugging off, you still get a readable run in chat:

- **Activity** lines such as `Calling read_file` when each tool starts (not part of saved conversation history).
- **Tools & Logs** in the nav rail plus **Execution Detail** in the utility panel for full prompts, tool arguments, and outputs.

Click an older log row to **pin** the inspector on that step; click the **latest** row to follow the live trace again.

## Step limit

**Max steps** in Settings caps how many LLM round-trips one send can take (default 20). The status bar shows the current step during a run. If the cap is hit while the model still requested tools, the assistant adds a brief step-limit message instead of ending silently.

## Max output tokens and truncation

**Max Output Tokens** in **Settings → Agent Behavior** limits how much the model can generate in one completion (default **16384** for new installs). Agent runs that emit large tool-call JSON or long replies need enough headroom; values below about **2048** often truncate tool arguments and break the loop.

When a completion is cut off (`finish_reason` length), the agent **retries once or twice** with a temporarily higher output budget (up to 16384) before accepting the result. Final assistant text may include a short note if output was still incomplete.

## Context summarization

Enable **Auto-summarize when nearing context limit** (on by default) to compress **older** chat turns into a summary message while keeping recent turns verbatim. This runs **before** a step when estimated prompt size crosses your threshold, or **reactively** when the provider returns a context-length error.

Optional fields on the same tab:

- **Context window (tokens)** — model context size used for proactive threshold (default 128000 for long-context models).
- **Summarize threshold** — fraction of usable prompt budget before summarizing (default 0.85).

When summarization runs, chat shows a brief assistant note: *Context summarized to continue the conversation.*

## Cancel and exit

Use **Stop** / cancel in the chat UI to abort an active run. Quitting the app with runs in progress should prompt to stop them cleanly.
