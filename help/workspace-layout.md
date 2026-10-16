# Workspace layout and panels

The main window is an IDE-style layout: navigation on the left, a tabbed center area, optional side panels, and an optional bottom terminal.

## Navigation rail

The narrow left **activity bar** switches views:

- **Workspace** — workspace overview.
- **Projects** — file tree for the workspace.
- **Agents** — chat session list (active and archived).
- **Bots** — agent presets and prompt setups.
- **Tools & Logs** — per-step execution log for the active session: user prompts, model steps (`Step N/M · Model:`), and each tool’s input/output (`Step N/M · tool_name(...)`). Click a row to open **Execution Detail**; during an active run new rows follow into that panel until you select an older row.
- **Tasks & Plans** — session task list from the todo tool.
- **Tool Errors** — failed tool calls for the active session (click a row for full arguments and output). The subtitle shows the on-disk log path; hover for the full path.

A horizontal rule on the rail separates **Future Features** (roadmap placeholders with no backend yet). Each opens a panel with a bold **COMING SOON** banner above the planned capabilities list:

- **Multi-Agent Workspace** — specialised agents that collaborate on delivery.
- **Execution Plans** — numbered plans, tasks, and progress tracking.
- **Workspace Knowledge Base** — workspace RAG and document sources.
- **The Brain** — optional adaptive learning and memory.

The same entries appear under **Workspace → Future Features** in the menu.

Icons are tooltipped; the active rail button stays **down** (speed-button group).

### Tool error log file

Failures are also appended to `tool-errors.log` under the same user config folder as chat sessions (`lazycodingagent` beside session storage). The path is resolved at runtime on **Windows, Linux, and macOS** (see the Tool Errors panel subtitle). The file is JSONL (one JSON object per line). Clearing the panel only clears the in-memory list for the current session; delete the file manually if you want to reset the on-disk history.

## Center area

The center header tab strip switches three **PageControl** pages (no **+** on this strip):

- **Chat** — a **session tab strip** under the page header lists every non-archived chat (**+** for new session, **✕** to archive). Below that: conversation history rendered as **Markdown** (headings, bold, code, lists — subset, not full GFM), current session label, composer, mode and model combos, Stop and Run.
- **Editor** — one `SynEdit` buffer for the file you opened from Projects (prompted to save if dirty before replacing). Font size scales with display DPI.
- **Markdown** — formatted preview when you open a `.md` file and choose **Preview** (same HTML renderer as chat). Choose **Source** to edit in the Editor tab.

There are **no** per-file editor tabs. Switch sessions from the Chat session tabs or **Sessions** in the nav rail; open another file from **Projects**.

## Right and utility panels

- **Guidelines / instructions** — workspace context on the right when enabled.
- **Utility panel** — `PageControl` with **Scratchpad**, **Execution Detail**, and **Plan**. Toggle via **Window → Panels → Utility Panel**. **Execution Detail** renders formatted HTML: accent section headers, highlighted tool names, shaded JSON blocks (pretty-printed), and prose blocks for long prompt text.

## Panel visibility and detach

Use **✕** on navigation, guidelines, utility, or terminal panel headers, or **Window → Panels**, to show or hide those areas. The **center (chat / editor / markdown)** area has **⧉ detach** on its header but no **✕** — hide the chat panel from **Window → Panels** only. Layout and visibility persist when you restart the app.

Use **⧉** on navigation, chat, guidelines, utility, and terminal headers to **detach** the panel into a floating window (position and size are saved). Close the float window or click **⧉** again to re-dock.

## Terminal

**View → Terminal** opens a bottom dock with a real shell in the **workspace root**. Resize with the splitter above the status bar. On Linux, the embedded terminal needs PTY support (see README).

## Theme

**View → Toggle Light / Dark Theme** switches the in-app palette. The **application menu** is an in-window **`TLcaThemedMenuBar`** (same on Windows, Linux, and macOS—not the macOS screen menu bar). Lists, memos, combos, menu dropdowns, and markdown preview areas follow the active theme (`LcaTheme` in the LCA Design package). On **Windows**, scrollbars on scrollable controls (lists, tree, memos, editor, chat history, terminal bar) use the same palette via `LcaThemeWin32ScrollBars.pas`. Primary, cancel, and destructive action buttons use the app palette on **Windows** (custom-painted buttons via `LcaThemeWin32Buttons.pas`). On **Linux and macOS**, buttons and scrollbars otherwise use the native widget set; custom tab strips (`TLcaThemedPageTabBar`) are painted by the app.

## Tips

- Use splitters between panels to resize.
- Combo **Height** is set in the Lazarus form (chat footer, plan header, Settings). Theme styling does not override that size; if a combo looks wrong after a resize, try toggling theme once.
