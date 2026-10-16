# How the agent works

This section is for learning how LazyCodingAgent ties together the LLM, tools, and UI. The implementation lives mainly in `uAgentEngine`, `uAgentTools`, and `uChatSessionHub`.

## What runs when you send a message

1. Your prompt is attached to the **current chat session**.
2. That session owns one **agent engine** instance (conversation history + tool registry).
3. A **background thread** runs the agent loop so the UI stays responsive.
4. The UI receives events for new messages, tool calls, and state (thinking, executing tools, finished, error).

You can start runs in multiple sessions; each engine is independent.

## The ReAct loop (reason + act)

After you send a message, the engine roughly does:

1. Build or refresh the **system prompt** (mode, workspace path, tool list, project rules).
2. Append your message to the conversation.
3. Optionally **compact history** when auto-summarize is enabled and the prompt is near the configured context window (`uChatContextManager`).
4. Call the **LLM** with the message list and tool definitions. If output is truncated by **Max Output Tokens**, the engine may retry with a higher temporary limit before continuing.
5. If the model returns **tool calls**, run each tool locally and append **tool result** messages (including JSON with an `error` field when a tool fails).
6. Repeat steps 3–5 until the model answers **without** tool calls, you **cancel**, or a **step limit** is reached (default 20 steps).

Unexpected tool exceptions are caught at the tool boundary, converted to the same error JSON shape, and returned to the model so the loop can continue instead of stopping under the debugger.

This pattern is often called **ReAct**: the model reasons in natural language, then acts via tools, then reasons again on the results.

```
You → system + history → (optional summarize) → LLM → (optional tools) → LLM → … → final reply
```

## What goes into the system prompt

- **Workspace mode** (Ask / Plan / Agent) — controls which tools are advertised.
- **Workspace root** — all file paths are resolved relative to this folder.
- **Tool guidance** — short descriptions and JSON parameter shapes for allowed tools.
- **Project rules** — combined text from `<workspace>/.rules/*.md`.

The model only sees tools that are **allowed in the current mode**.

## Modes vs file changes

| Mode | Typical use | Mutations |
|------|-------------|-----------|
| Ask | Explain code, search, read | No writes, patch, or shell |
| Plan | Specs and checklists | Can write `.plan/plan-*.md` only |
| Agent | Implement and fix | Writes, patches, shell, builds |

Plan and Ask still use read/search/git tools to understand the tree.

## What you see in the UI

- **Assistant messages** — model text and (in debugging mode) full tool JSON in chat.
- **Activity lines** — while a run is in progress, chat shows short **Calling …** lines when the model invokes a tool (display only; not sent back to the model). These lines are not kept when the transcript is reloaded from saved messages.
- **State** — idle, thinking, executing tool, finished, or error. During a run the status bar includes **step N/M** (for example `Thinking... (step 2/20)`), where **M** is **Max steps** from Settings.
- **Execution log** (navigation **Tools & Logs**) — per-step trace with plain captions (`User:`, `Step N/M · Model:`, `Step N/M · tool_name(...)`). Click a row to inspect it in the utility **Execution Detail** panel. While a run is active, new log rows **follow** into Execution Detail automatically unless you click an older row (click the latest row again to resume follow).
- **Step limit** — if the loop uses all allowed steps and the model still wanted tools, the assistant posts a short note that the step limit was reached (configure **Max steps** in Settings).
- **Tool Errors** — failed tools for the session, plus a shared `tool-errors.log` file under your user config folder.

Sending a prompt opens the **utility panel** on **Execution Detail** so you can watch the enriched prompt and each step during a demo or debug session. The inspector uses themed HTML (section headers, tool-call highlights, JSON in distinct blocks) rather than a plain text dump.

## Safety and sandboxing

- File tools resolve paths under the **workspace root**; escapes outside the project are rejected.
- The **git** tool is **read-only** (status, diff, log, show).
- **Shell** runs with a timeout cap; use Agent mode only when you trust the workspace and model.

## Learn more

See **Agent tools reference** for each tool name, what it does, and which modes allow it.
