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
3. Call the **LLM** with the full message list and tool definitions.
4. If the model returns **tool calls**, run each tool locally and append **tool result** messages (including JSON with an `error` field when a tool fails).
5. Repeat step 3–4 until the model answers **without** tool calls, you **cancel**, or a **step limit** is reached (default 20 steps).

Unexpected tool exceptions are caught at the tool boundary, converted to the same error JSON shape, and returned to the model so the loop can continue instead of stopping under the debugger.

This pattern is often called **ReAct**: the model reasons in natural language, then acts via tools, then reasons again on the results.

```
You → system + history → LLM → (optional) tools → LLM → … → final reply
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

- **Assistant messages** — model text and (in debugging mode) tool payloads.
- **State** — idle, thinking, executing tool, finished, or error.
- **Execution log** (navigation **Tools & Logs**) — deeper request context for learning and debugging.
- **Tool Errors** — failed tools for the session, plus a shared `tool-errors.log` file under your user config folder.

## Safety and sandboxing

- File tools resolve paths under the **workspace root**; escapes outside the project are rejected.
- The **git** tool is **read-only** (status, diff, log, show).
- **Shell** runs with a timeout cap; use Agent mode only when you trust the workspace and model.

## Learn more

See **Agent tools reference** for each tool name, what it does, and which modes allow it.
