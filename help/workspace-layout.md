# Workspace layout and panels

The main window is a dockable IDE-style layout: navigation on the left, chat in the center, optional side panels, and an optional bottom terminal.

## Title bar and menu

The main window uses a **borderless frame** with a custom **title bar** (app name, drag to move, double-click to maximize) and **window controls** (minimize, maximize/restore, close) that follow the active light/dark theme. On macOS the controls use the familiar left-side traffic-light layout; on Windows and Linux they sit on the right.

The **menu bar** (File, View, Workspace, …) is a separate row directly under the title bar. Menu commands and keyboard shortcuts are unchanged.

## Navigation rail

The narrow left **activity bar** switches views:

- **Home** — workspace overview.
- **Projects** — file tree for the workspace.
- **Sessions** — chat session list (active and archived).
- **Bots** — agent presets and prompt setups.
- **Tools & Logs** — per-step tool execution log for the active session (click a row to open detail in the utility panel).
- **Tasks & Plans** — session task list from the todo tool.
- **Tool Errors** — failed tool calls for the active session (click a row for full arguments and output). The subtitle shows the on-disk log path; hover for the full path.

Icons are tooltipped; the active item is highlighted.

### Tool error log file

Failures are also appended to `tool-errors.log` under the same user config folder as chat sessions (`lazycodingagent` beside session storage). The path is resolved at runtime on **Windows, Linux, and macOS** (see the Tool Errors panel subtitle). The file is JSONL (one JSON object per line). Clearing the panel only clears the in-memory list for the current session; delete the file manually if you want to reset the on-disk history.

## Chat and center area

The center hosts the chat panel with session tabs, message history, and the composer (mode + model + prompt).

## Right and utility panels

- **Guidelines / instructions** — workspace context on the right when enabled.
- **Utility panel** — extra tabbed area (plans, execution detail, etc.). Toggle via **Window → Panels → Utility Panel**. It can be detached like other panels.

## Detachable panels

Most panels can **detach** into floating windows (header **Detach** or **Window** menu) and **dock** back with **⇲ Dock**.

Detached position and visibility persist when you restart the app.

## Terminal

**View → Terminal** opens a bottom dock with a real shell in the **workspace root**. Detach and resize like other panels. On Linux, the embedded terminal needs PTY support (see README).

## Theme

**View → Toggle Light / Dark Theme** switches the in-app palette. Combo boxes, tabs, and lists follow the active theme.

## Tips

- Use splitters between panels to resize.
- If a combo or panel layout looks wrong after detach, try toggling theme once; the app guards against common LCL layout loops.
