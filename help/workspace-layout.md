# Workspace layout and panels

The main window is an IDE-style layout: navigation on the left, a tabbed center area, optional side panels, and an optional bottom terminal.

## Navigation rail

The narrow left **activity bar** switches views:

- **Home** — workspace overview.
- **Projects** — file tree for the workspace.
- **Sessions** — chat session list (active and archived).
- **Bots** — agent presets and prompt setups.
- **Tools & Logs** — per-step tool execution log for the active session (click a row to open detail in the utility panel).
- **Tasks & Plans** — session task list from the todo tool.
- **Tool Errors** — failed tool calls for the active session (click a row for full arguments and output). The subtitle shows the on-disk log path; hover for the full path.

A horizontal rule on the rail separates **Future Features** (roadmap placeholders — **Coming Soon**, no backend yet):

- **Multi-Agent Workspace** — specialised agents that collaborate on delivery.
- **Execution Plans** — numbered plans, tasks, and progress tracking.
- **Workspace Knowledge Base** — workspace RAG and document sources.
- **The Brain** — optional adaptive learning and memory.

The same entries appear under **Workspace → Future Features** in the menu.

Icons are tooltipped; the active rail button stays **down** (speed-button group).

### Tool error log file

Failures are also appended to `tool-errors.log` under the same user config folder as chat sessions (`lazycodingagent` beside session storage). The path is resolved at runtime on **Windows, Linux, and macOS** (see the Tool Errors panel subtitle). The file is JSONL (one JSON object per line). Clearing the panel only clears the in-memory list for the current session; delete the file manually if you want to reset the on-disk history.

## Center area

The center uses a **PageControl** with three fixed tabs:

- **Chat** — conversation history (plain text), current session label, composer, mode and model combos, Stop and Run.
- **Editor** — one `SynEdit` buffer for the file you opened from Projects (prompted to save if dirty before replacing).
- **Markdown** — read-only preview memo for markdown files (source editing uses the Editor tab).

There is **no** session tab strip and **no** per-file editor tabs. Switch sessions from **Sessions** in the nav rail; open another file from **Projects**.

## Right and utility panels

- **Guidelines / instructions** — workspace context on the right when enabled.
- **Utility panel** — `PageControl` with **Scratchpad**, **Execution Detail**, and **Plan**. Toggle via **Window → Panels → Utility Panel**.

## Panel visibility

Use **✕** on a panel header or **Window → Panels** to show or hide navigation, guidelines, utility, and terminal. Layout and visibility persist when you restart the app.

## Terminal

**View → Terminal** opens a bottom dock with a real shell in the **workspace root**. Resize with the splitter above the status bar. On Linux, the embedded terminal needs PTY support (see README).

## Theme

**View → Toggle Light / Dark Theme** switches the in-app palette. Lists, memos, and combos follow the active theme; native page-control tabs and buttons follow the OS widget set on Linux and macOS.

## Tips

- Use splitters between panels to resize.
- If a combo looks wrong after a resize, try toggling theme once; chat footer combos use fixed heights in the form resource to match theme metrics.
