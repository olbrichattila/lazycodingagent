# LazyCodingAgent

LazyCodingAgent is a cross-platform desktop AI coding assistant and editor built with Free Pascal and Lazarus (LCL). Inspired by tools such as Hermes, Cursor, and Codex, it provides a focused, high-productivity development workspace.

> **Status:** Multi-window workspace layout implemented. AI/model execution is in active integration.

## Key Features & Workspace Layout

### 1. Lazarus Visual Form Designer Architecture
- Designed directly with Lazarus Visual Designer (`mainunit.lfm` and `mainunit.pas`).
- Visually inspect, arrange, and drop new LCL components directly onto the form in the IDE.
- Published event handlers hooked cleanly into the state management and theme engine.

### 2. Modern Dark-First Design & Cohesive Dropdowns
- Crisp, modern theme with prominent boundary lines (`BorderStrong` and `Border` tokens) and high-contrast styling.
- **Custom-styled dark dropdown menus**: Combo box dropdowns in the chat composer match the sleek black-style design flow on dark mode and adjust cleanly for light mode.
- **Stable cross-platform combo layout**: themed combo boxes use centralized metrics in `uTheme.pas` (`StyleComboBox`, `EffectiveThemedComboBoxHeight`, `ThemedComboBoxItemHeight`); manual footer layout in `TChatPanel` uses the effective widget height after styling, with `FUpdatingLayout` re-entrancy guards.
- **Themed tab strips**: center editors, chat sessions, utility panel, and Settings use [`fraThemedTabs.pas`](fraThemedTabs.pas) (`TThemedTabHostFrame`) with canvas-drawn headers for reliable dark/light styling on Qt5/Linux (native `TPageControl` tab headers are not used for these areas).
- **Themed buttons**: dialogs and panel chrome use [`fraThemedButton.pas`](fraThemedButton.pas) (`TThemedButtonFrame`) so actions follow the palette on Qt5/Linux (native `TButton` does not).
- **Clean Minimalist Top**: Full vertical viewport space for navigation, chat, and guidelines panels, with comprehensive menu bar and status bar controls.
- Seamless Dark Mode default with instant Light Mode toggle via `View > Toggle Light / Dark Theme`.
- **Navigation rail** built from `TSpeedButton` controls on the main form (icon captions, tooltips, accent selection indicator).
- **Accent text selection** on chat and navigation lists (owner-drawn rows — blue text, no OS highlight band).
- **Themed action buttons**: standard `TButton` controls styled with `StylePrimaryButton`, `StyleCancelButton`, and `StyleDestructiveButton` in `uTheme.pas`. Fill and font colors apply on **Windows** (after clearing the native button theme). On **Linux (GTK)** and **macOS (Cocoa)** those colors are ignored; buttons stay native.
- **Cross-platform UI**: icon-only nav rail, owner-draw list accent selection, and theme tokens apply on all LCL targets.
- **Scrollbars / title chrome**: on **Windows**, `ApplyPlatformChrome` uses immersive dark mode and `DarkMode_Explorer` for native scrollbars; on **Linux and macOS**, scrollbars and window chrome follow the **OS widget theme** (align the system GTK/Cocoa dark mode with the in-app dark theme for best results).
- **Linux main menubar**: in-app dark/light toggle syncs the native top menu bar (File, View, …) via the LCL widgetset — Qt5 `QMenuBar` stylesheet, or GTK2/GTK3 colors/CSS — so labels stay readable; dropdown menus are left on the OS theme.
- Clean splitters allowing custom width resizing between all panels.

#### Platform verification checklist

| Check | Windows | Linux (GTK) | macOS (Cocoa) |
|-------|---------|-------------|---------------|
| Nav rail icons + accent selection | Yes | Yes | Yes |
| List rows: accent text, no blue band | Yes | Yes | Yes |
| Primary / Cancel / Stop buttons (`TButton` + `uTheme`) | Colored via `Style*` helpers | Native GTK button | Native Cocoa button |
| Dark scrollbars matching app surface | Themed via Win32 | OS GTK theme | OS AppKit theme |
| Light/dark toggle coherent | Yes | Yes | Yes |
| Main menubar readable in app dark mode | Yes | Yes (Qt5/GTK) | OS menu |

### 3. Detachable Multi-Window Architecture
- Panels are docked to the main window by default and can be detached into independent, floating `TForm` windows.
- Floating windows can be moved to separate monitors across Windows, Linux, and macOS.
- Detached panels use a small floating `TForm` (`uPanelDetach.pas`); redock via the **Window** menu or by closing the floating window.
- Panel chrome (title + **Detach** / hide) uses standard `TPanel` + `TButton` on the main form.
- Panel visibility and floating window coordinates are persisted in configuration settings.

### 4. Vertical Navigation Rail & Panel
- Sleek 56px left navigation rail with icon-only slots, tooltips, and accent active indicator for:
  - **⌂ Home**: Workspace dashboard and overview.
  - **◫ Projects**: Project explorer and file tree.
  - **💬 Sessions**: Per-workspace chat sessions (active and archived lists, archive/restore/delete actions).
  - **⚡ Bots**: Custom coding agents and prompt setups.
- Connected content area with contextual actions for the active navigation selection.

### 5. Primary AI Agent & Chat Workspace
- **Multiple parallel sessions** per workspace: each session has its own `TAgentEngine` and async run thread. Switch sessions (left **Sessions** nav or chat tab strip) without stopping other sessions. Background runs continue when you switch workspace and return later.
- **New chat:** primary path is the left rail **Sessions** view → **+ New Chat Session**; shortcut **+** in the chat header (next to session tabs) also creates a session and focuses the center Chat tab.
- **Session tabs** above the chat panel for quick switching; closing a tab **archives** that session (not a permanent delete). Archiving the last open tab opens a fresh empty session automatically.
- **Archive** via Sessions panel (**Archive Session** / **Restore Session**), `Delete` on an active session, or `Shift+Delete` to permanently delete an archived session.
- Clean hero greeting: `What should we build in <project name>?`.
- Embedded workspace badge and live conversation history stream.
- Multiline prompt composer with mode dropdown selector:
  - **Ask**: Fast Q&A without direct workspace mutations.
  - **Plan**: Architecture design, checklists, and specs.
  - **Agent** (*Default*): Full autopilot coding and editing.
- Instant mode and model switching synced with application state and status bar.
- Model selector dropdown supporting `anthropic/claude-3.7-sonnet`, `Hermes-4-70B`, `Hermes-4-405B` (Nous Research), `openai/gpt-4o`, `deepseek/deepseek-r1`, etc. (OpenRouter slugs where noted).

### 6. In-app User Guide
- **Help → User Guide…** (F1) opens a searchable help browser with topics under [`help/`](help/), including how the agent and tools work.
- After `lazbuild`, the build copies `help/` next to the executable; when developing from the IDE, topics also resolve from the project `help/` folder.

### 7. Debugging mode and project rules
- **Debugging Mode** (Settings → Agent Behavior): when enabled, full tool JSON results appear in the chat history; when disabled, only tool errors are shown (successful tool calls stay hidden in chat).
- **Project Rules** (main menu → Workspace → Project Rules…): edit per-workspace Markdown files under `<workspace>/.rules/*.md`. Combined rule text is injected into the agent system prompt for Ask, Plan, and Agent modes.

### 8. Reserved Context & Instructions Panel
- Dedicated right-side panel for workspace guidelines, coding rules, and instructions context.

### 9. Detachable Utility / Blank TabPage Panel (Right Corner)
- Extra right-corner **utility panel** with themed tabs (scratchpad, execution detail, dynamic plan tabs).
- **Invisible by default**: Starts hidden to keep the workspace streamlined and distraction-free.
- **Toggleable & Detachable**: Can be toggled on/off at any time via `Window > Panels > Utility Panel` or detached to a floating multi-monitor window via `Window > Detach Utility Panel to Window` or panel header icon.

### 10. Integrated terminal (bottom panel)
- **View → Terminal** toggles a full-width bottom dock (above the status bar) with a real PTY shell (`$SHELL` / `/bin/bash` on Unix, `%COMSPEC%` on Windows).
- **Detachable** like other panels (`Window` menu or header **Detach**); layout persists as `Panel_4` (visible, floating bounds, `DockedHeight` for the bottom strip).
- Docked height defaults to about **one quarter** of the client area (resizable splitter); floating window size is stored separately from docked height.
- When you open the panel with an active workspace, the shell starts in the **workspace root** (`pwd` / `cd`); switching workspaces restarts the shell in the new folder if the terminal is already visible.
- Powered by the [TerminalEmulator](https://github.com/andrewd207/TerminalEmulator) submodule (`third_party/TerminalEmulator`). **Windows** requires Windows 10 1809+ (ConPTY).
- **Linux PTY:** the embedded terminal needs `forkpty` from **libutil** (Debian/Ubuntu: `bsdutils` / `util-linux`). Build the submodule packages via `./scripts/build-terminal-deps.sh` before compiling the app. If the panel stays blank, check the status bar for a PTY error and verify `$SHELL` or `/bin/bash` exists.

#### Terminal manual test checklist

| Step | Linux / macOS | Windows |
|------|----------------|---------|
| View → Terminal shows bottom panel | `pwd` matches workspace | `cd` matches workspace |
| Resize splitter; restart app | Height restored | Height restored |
| Detach / dock panel | Works on second monitor | Works on second monitor |
| Theme toggle | Colors readable | Colors readable |
| Interactive TUI | `ls` colors; optional `vim`/`nano` | `dir`, `git status` |

---

## Technology Stack

- [Free Pascal (FPC)](https://www.freepascal.org/)
- [Lazarus IDE](https://www.lazarus-ide.org/)
- Lazarus Component Library (LCL)
- **TurboPowerIPro** (Lazarus package; IpHtml markdown chat transcript in `uMarkdownView.pas`)

---

## Building & Running

Clone with submodules (required for the integrated terminal). Without them, Lazarus shows a broken dependency on **TerminalFramework**:

```bash
git clone --recurse-submodules <repo-url>
# or after clone:
git submodule update --init third_party/TerminalEmulator
```

On Windows (PowerShell), the same init step:

```powershell
git submodule update --init third_party/TerminalEmulator
```

Register and compile the terminal Lazarus packages once per machine (or after updating the submodule):

**Linux / macOS:**

```bash
./scripts/build-terminal-deps.sh
```

**Windows:**

```powershell
.\scripts\build-terminal-deps.ps1
```

If `lazbuild` is not on `PATH`, set `$env:LAZBUILD` to your `lazbuild.exe` (for example `C:\lazarus\lazbuild.exe`).

**Form designer (no extra Lazarus package):** Dialogs and `mainunit` stream **stock LCL** types in `.lfm` (`TButton`, `TPanel` tab hosts). At runtime, [`fraThemedButton.pas`](fraThemedButton.pas) upgrades placeholders via `EnsureThemedButton` / `Style*Button`, and [`fraThemedTabs.pas`](fraThemedTabs.pas) creates `TThemedTabHostFrame` on host panels via `EnsureThemedTabHost`. Edit forms from the **`.pas`** unit (**View → Toggle Form Unit** / F12), not a standalone `.lfm` tab.

Open `lazycodingagent.lpi` in Lazarus (install **TerminalFramework** and **ViewLCL** from `third_party/TerminalEmulator/` if the IDE still prompts after the script), or build from the command line:

**Linux / macOS:**

```bash
./scripts/build-terminal-deps.sh
lazbuild lazycodingagent.lpi
```

The project pins **Qt5** in `lazycodingagent.lpi` (`LCLWidgetType`). After opening the project in Lazarus, run **Run → Build** (Ctrl+F9) once so the toolbar Run button turns green; Messages should show `-dLCLqt5` on the compile line.

**Windows:**

```powershell
.\scripts\build-terminal-deps.ps1
lazbuild lazycodingagent.lpi
```

**IDE-only install (any OS):** Package → Open package file → `third_party/TerminalEmulator/TerminalFramework/TerminalFramework.lpk` → Compile → Use → Install; repeat for `ViewLCL/ViewLCL.lpk`; then reopen `lazycodingagent.lpi`.

If the Lazarus IDE hangs when opening this project, quit Lazarus, rename or remove `lazycodingagent.lps` in the project directory (session file; regenerated on save), then open `lazycodingagent.lpi` again.

### HTTPS for LLM providers (Fetch Models, chat, agent)

All HTTPS traffic goes through [`uLlmClient.pas`](uLlmClient.pas) (Settings **Fetch Models**, agent completions).

| Platform | Transport | Notes |
|----------|-----------|--------|
| **Windows** | WinHTTP + Schannel ([`uWindowsHTTP.pas`](uWindowsHTTP.pas)) | No OpenSSL DLLs beside the exe |
| **Linux / macOS** | `fphttpclient` + `opensslsockets` | System OpenSSL must be installed and visible to FPC (typical Lazarus Linux builds; on macOS often Homebrew `openssl@3` or system libs). Socket `IOTimeout` is in **milliseconds**, matching `TLlmClient.TimeoutMs` (default 60s). |

If Fetch Models or chat fails with an OpenSSL initialization error on Linux/macOS, install SSL development libraries for your distro and ensure Lazarus was built with SSL support. The app surfaces a dialog instead of crashing when SSL is unavailable.

---

## Architecture & Unit Structure

- `lazycodingagent.lpr` — Application entry point
- `mainunit.pas` / `mainunit.lfm` — Main form designed with Lazarus Form Designer (`TLazyCodingAgentForm`): menus, splitters, status bar, dock hosts, tab host panels (runtime `TThemedTabHostFrame`), and panel chrome (`TPanel` + designer `TButton` placeholders)
- `uPanelDetach.pas` — Reparents a content panel into a runtime `TForm` for floating windows (Windows, Linux, macOS); redock via the Window menu or by closing the float
- `uTerminalPanel.pas` — Embedded PTY terminal (`TTerminalPanel` wrapping TerminalEmulator ViewLCL)
- `third_party/TerminalEmulator/` — Git submodule: TerminalFramework + ViewLCL packages
- `uNavigationPanel.pas` — Navigation content views (`TNavContentControl` on the main form)
- `uChatPanel.pas` — Composer card, Ask/Plan/Agent mode dropdown, model selector, and markdown message stream
- `uMarkdownView.pas` — Theme-aware markdown → HTML renderer (`TIpHtmlPanel`) with auto-scroll-to-bottom
- `uChatSessionStore.pas` — Per-workspace JSON persistence for chat sessions (messages, archive flag)
- `uChatSessionHub.pas` — Per-workspace session hub: one `TAgentEngine` per session, parallel runs, save/shutdown
- `uWorkspaceState.pas` — State management and INI persistence for bounds, docking, modes, and themes
- `fraThemedTabs.pas` / `fraThemedTabs.lfm` — Designer `TFrame` with canvas-drawn tab strip (`+`, per-tab `×` hit zones) and `pnlPages` for tab bodies
- `fraThemedButton.pas` / `fraThemedButton.lfm` — `TThemedButtonFrame` (primary/cancel/destructive roles, modal `ModalResult`); upgraded from designer `TButton` at runtime
- `uTheme.pas` — Dark/light design tokens, platform chrome (`ApplyPlatformChrome`), ComboBox/list owner-draw, `PaintThemedButton`
- `uAppTypes.pas` — Shared enumerations, modes, and helpers
- `uAgentTypes.pas` — Chat roles, LLM providers, tool schemas, and token usage records
- `uAgentEngine.pas` — Autonomous ReAct execution loop, state management, and LLM communication
- `uAgentRules.pas` — Per-workspace `.rules/*.md` load/save for project rules
- `frmWorkspaceRules.pas` / `frmEditRule.pas` — Project rules editor (main menu)
- `uAgentToolBase.pas` — Base tool abstract class (`TAgentTool`), session context, JSON helpers (`ToolError`, `ToolResultFromJson`), mode gating
- `uAgentToolPaths.pas` — Workspace path sandbox, byte I/O, glob matching, symlink/reparse handling
- `uToolProcessCore.pas` — Shared subprocess runner (stdout/stderr caps, timeouts, changed-path tracking)
- `uAgentTools.pas` — Tool factory and registry (`TAgentToolRegistry`) aggregating modular tool classes
- `uToolReadFile.pas` — `read_file` (16 MiB cap, UTF-8/binary checks)
- `uToolWriteFile.pas` — `write_file`
- `uToolApplyPatch.pas` / `uToolEditFile.pas` — `apply_patch` unified diff and `edit_file` search-replace
- `uToolListDirectory.pas` / `uToolGlob.pas` — directory listing and glob (500 entry cap)
- `uToolSearchCode.pas` — `search_code` / alias `grep` (regex, 500 match cap)
- `uToolRunProcess.pas` — `shell` (aliases `terminal`, `run_process`); Windows uses `cmd.exe /C`, Unix uses `/bin/sh -c`
- `uToolDiagnostics.pas` — cached diagnostics + Agent-mode builds (auto-detected toolchains or explicit `command`)
- `uBuildTargetResolver.pas` — maps workspace targets/manifests to build invocations
- `uToolGit.pas` — read-only git inspect (status/diff/log/show)
- `uToolCreatePlanFile.pas` — Plan-mode `.plan/plan-*.md` writer
- `uToolTodo.pas` — session task list (alias `plan`)
- `uMainWorkspace.pas` — Compatibility alias unit

### Agent tools (JSON contract)

Advertised tools: `read_file`, `write_file`, `list_directory`, `glob`, `search_code`, `apply_patch`, `edit_file`, `shell`, `diagnostics`, `git`, `todo`, `create_plan_file`.

Tool messages returned to the LLM are **JSON strings**. Failures include an `error` field; patch failures often add `error_kind` (`context_mismatch`, `format`, `hunk_count_mismatch`, `incomplete_hunk`, `invalid_hunk`, `empty_patch`, `patch_apply`), plus optional `path`, `line`, `hint`, and `partial` when a multi-file patch stops mid-batch. Successful `apply_patch` may include `warnings` when minor hunk headers were auto-corrected.

| Mode | Write / shell / patch | Plan files |
|------|------------------------|------------|
| Ask | Blocked | Blocked |
| Plan | Blocked | `create_plan_file` allowed |
| Agent | Full mutating set | Allowed |

### Running tool integration tests

### Manual check: parallel chat sessions

1. In workspace A, start an agent run in session 1; switch to session 2 (nav or tab) and start another run — both should finish; session 1 transcript updates when re-selected.
2. Switch to workspace B while A still has a run; return to A — run completed or still active; messages persisted.
3. Archive an active session — run stops; session appears under **Archived**; composer disabled until restored.
4. Close the app with multiple runs — confirm prompt to stop all runs; exit cleanly.
5. Toggle dark/light theme and resize the chat dock — no `ChangeBounds` loop.

Requires FPC, Lazarus `lazutils` on the unit path, and Python 3:

```bat
tests\run_tests.bat
```

```bash
tests/run_tests.sh
```

Builds `tests/tool_driver.lpr` and runs `tests/test_local_tools.py` (patch, path sandbox, shell, diagnostics fixtures ported from lazcodingagent).
