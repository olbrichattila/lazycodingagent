# Getting started

LazyCodingAgent is a desktop AI coding workspace. You open a **project folder** as a workspace, chat with an LLM in multiple **sessions**, and (in Agent mode) let the assistant read and change files under that folder using **tools**.

On launch, a **branded splash image** appears while the workspace starts (about one second after loading finishes). Window chrome follows your saved theme (dark by default, or light if you chose **View → Toggle Light / Dark Theme** last time).

## Open or create a workspace

1. Use **File → Open Project Folder** to point at an existing code tree, or create a workspace from the home flow when offered.
2. The status bar and chat hero show the active workspace name.
3. Panel layout, theme, and dock state are saved per workspace in application settings.

## Settings you need first

Open **Settings** from the menu (or when prompted):

- **LLM provider** — API key, base URL if needed, and default model.
- **Fetch Models** — loads model IDs from your provider (requires working HTTPS).
- **Agent Behavior** — optional **Debugging mode** to show full tool JSON in chat.

Save settings before starting a long agent run.

**Optional: web search** — No search API key? See **Help → Web Search** → **Local SearXNG with Docker**.

## Building from source (developers)

From the repository root, install Lazarus packages once per machine (`scripts/install-lca-lazarus` on your OS), then:

```bash
lazbuild lazycodingagent.lpi
./scripts/post-build.sh
```

That copies **help/** and **assets/** (splash image) next to the executable so **Help → User Guide** and the startup splash work outside the IDE. See the project **README** for Windows commands and CI details.

## HTTPS and OpenSSL (Linux / Raspberry Pi)

Chat, **Fetch Models**, and the agent need **HTTPS**. On Linux the app uses the system **OpenSSL 3** libraries.

- **arm64 `.deb` (Raspberry Pi OS, Debian, Ubuntu):** Installing the release package should pull in **`libssl3`** automatically. If HTTPS still fails after an upgrade, run `sudo apt install libssl3` (on some distros the package is named `libssl3t64`).
- **Built from source on the Pi:** Install the runtime before using AI features: `sudo apt install libssl3`. You do not need the `-dev` package to run the app.

Settings and chat show a clear error instead of crashing when OpenSSL is missing.

## Your first chat

1. In the left rail, open **Agents** and choose **+ New Chat Session** (or use **+** on the chat session tab strip).
2. Pick a **mode** in the composer footer (Ask, Plan, or Agent).
3. Choose a **model** from the combo beside it.
4. Type a prompt and send.

Use **Ask** for questions without file writes. Use **Agent** when you want the assistant to edit the project.

## Where to learn more

- **Workspace layout and panels** — navigation, center tabs, utility panel, terminal.
- **Chat, sessions, and modes** — parallel sessions, archive, mode differences.
- **How the agent works** — what happens after you press Send (educational overview).
