# Getting started

LazyCodingAgent is a desktop AI coding workspace. You open a **project folder** as a workspace, chat with an LLM in multiple **sessions**, and (in Agent mode) let the assistant read and change files under that folder using **tools**.

## Open or create a workspace

1. Use **File → Open Project Folder** to point at an existing code tree, or create a workspace from the home flow when offered.
2. The status bar and chat hero show the active workspace name.
3. Panel layout, theme, and dock state are saved per workspace in application settings.

## Settings you need first

Open **Settings** from the menu (or when prompted):

- **LLM provider** — API key, base URL if needed, and default model.
- **Fetch Models** — loads model IDs from your provider (requires working HTTPS; see README for platform notes).
- **Agent Behavior** — optional **Debugging mode** to show full tool JSON in chat.

Save settings before starting a long agent run.

## Your first chat

1. In the left rail, open **Sessions** and choose **+ New Chat Session**, or use **+** in the chat header.
2. Pick a **mode** in the composer (Ask, Plan, or Agent).
3. Choose a **model** from the dropdown.
4. Type a prompt and send.

Use **Ask** for questions without file writes. Use **Agent** when you want the assistant to edit the project.

## Where to learn more

- **Workspace layout and panels** — navigation, detachable windows, terminal.
- **Chat, sessions, and modes** — parallel sessions, archive, mode differences.
- **How the agent works** — what happens after you press Send (educational overview).
