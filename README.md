# LazyCodingAgent

LazyCodingAgent is a cross-platform desktop AI coding assistant and editor built with Free Pascal and Lazarus (LCL). Inspired by tools such as Hermes, Cursor, and Codex, it provides a focused, high-productivity development workspace.

> **Status:** Multi-window workspace layout implemented. AI/model execution is in active integration.

## Key Features & Workspace Layout

### 1. Lazarus Visual Form Designer Architecture
- Designed directly with Lazarus Visual Designer (`mainunit.lfm` and `mainunit.pas`).
- **LCA Design** palette ([`packages/LcaDesignSystem/`](packages/LcaDesignSystem/)): themed tab bars, buttons, combos, markdown view, terminal panel, and surfaces stream on `.lfm` forms after running [`scripts/install-lca-lazarus`](scripts/install-lca-lazarus.sh) (or `.bat` on Windows).
- Published event handlers hooked cleanly into the state management and theme engine ([`LcaTheme`](packages/LcaDesignSystem/src/LcaTheme.pas), [`uThemeHooks.pas`](uThemeHooks.pas)).

### 2. Modern Dark-First Design & Cohesive Dropdowns
- Crisp, modern theme with prominent boundary lines (`BorderStrong` and `Border` tokens) and high-contrast styling.
- **Custom-styled dark dropdown menus**: Combo box dropdowns in the chat composer match the sleek black-style design flow on dark mode and adjust cleanly for light mode.
- **Stable cross-platform combo layout**: combo **Height** and **ItemHeight** come from the form resource (`.lfm`); `StyleComboBox` in [`LcaTheme.pas`](packages/LcaDesignSystem/src/LcaTheme.pas) applies owner-draw theming without resizing controls. `EffectiveThemedComboBoxHeight` is for layout estimates only.
- **Designer-first layout**: the main window streams **LCA Design** and stock LCL controls in `.lfm` files (`TLcaThemedPageTabBar`, `TLcaThemedButton`, `TLcaThemedComboBox`, `TLcaMarkdownView`, `TLcaTerminalPanel`, `TSynEdit`, etc.). Open `mainunit.pas` in Lazarus (F12) to edit the full layout.
- **Native tabs and buttons** on Linux/macOS; on **Windows**, `Style*` helpers custom-paint primary/cancel/destructive button fills via [`LcaThemeWin32Buttons.pas`](packages/LcaDesignSystem/src/LcaThemeWin32Buttons.pas).
- **Clean Minimalist Top**: Full vertical viewport space for navigation, chat, and guidelines panels, with comprehensive menu bar and status bar controls.
- Seamless Dark Mode default with instant Light Mode toggle via `View > Toggle Light / Dark Theme`.
- **Navigation rail** built from `TSpeedButton` controls on the main form (icon captions, tooltips, accent selection indicator).
- **Accent text selection** on chat and navigation lists (owner-drawn rows — blue text, no OS highlight band).
- **Themed action buttons**: `TLcaThemedButton` and stock `TButton` controls styled with `StyleThemedButtonRole` / `StylePrimaryButton` in [`LcaTheme.pas`](packages/LcaDesignSystem/src/LcaTheme.pas). On **Windows**, fills are drawn by `PaintThemedButton` through a Win32 paint subclass in [`LcaThemeWin32Buttons.pas`](packages/LcaDesignSystem/src/LcaThemeWin32Buttons.pas). On **Linux (GTK)** and **macOS (Cocoa)**, `TButton.Color` tints the native widget; no custom paint hook.
- **Cross-platform UI**: icon-only nav rail, owner-draw list accent selection, and theme tokens apply on all LCL targets.
- **Scrollbars / title chrome**: on **Windows**, scrollbars on lists, memos, the editor, markdown preview, and similar controls are painted from the app palette via [`LcaThemeWin32ScrollBars.pas`](packages/LcaDesignSystem/src/LcaThemeWin32ScrollBars.pas) (immersive dark title bar via `ApplyPlatformChrome`); combo/edit fields still use Explorer subthemes where needed. On **Linux and macOS**, scrollbars and window chrome follow the **OS widget theme** (align the system GTK/Cocoa dark mode with the in-app dark theme for best results).
- **Linux main menubar**: in-app dark/light toggle syncs the native top menu bar (File, View, …) via the LCL widgetset — Qt5 `QMenuBar` stylesheet, or GTK2/GTK3 colors/CSS — so labels stay readable; dropdown menus are left on the OS theme. **macOS** uses the native menu bar (no in-app menubar sync).
- Clean splitters allowing custom width resizing between all panels.

#### Platform verification checklist

| Check | Windows | Linux (GTK) | macOS (Cocoa) |
|-------|---------|-------------|---------------|
| Nav rail icons + accent selection | Yes | Yes | Yes |
| List rows: accent text, no blue band | Yes | Yes | Yes |
| Primary / Cancel / Stop buttons (`TLcaThemedButton` / `TButton` + `LcaTheme`) | Custom-painted via `LcaThemeWin32Buttons` | Native GTK (`TButton.Color`) | Native Cocoa (`TButton.Color`) |
| Scrollbars matching app light/dark palette | Custom-painted (`LcaThemeWin32ScrollBars`) | OS GTK theme | OS AppKit theme |
| Light/dark toggle coherent | Yes | Yes | Yes |
| Main menubar readable in app dark mode | Yes | Yes (Qt5/GTK) | OS menu |

### 3. Docked panels (show / hide)
- Navigation, guidelines, utility, and terminal panels dock on the main form.
- **Window → Panels** and panel **✕** buttons toggle visibility; sizes and visibility persist in workspace settings.

### 4. Vertical Navigation Rail & Panel
- Sleek 56px left navigation rail with icon-only slots, tooltips, and accent active indicator for:
  - **⌂ Home**: Workspace dashboard and overview.
  - **◫ Projects**: Project explorer and file tree.
  - **💬 Sessions**: Per-workspace chat sessions (active and archived lists, archive/restore/delete actions).
  - **⚡ Bots**: Custom coding agents and prompt setups.
- Connected content area with contextual actions for the active navigation selection.

### 5. Primary AI Agent & Chat Workspace
- **Multiple parallel sessions** per workspace: each session has its own `TAgentEngine` and async run thread. Switch sessions from the left **Sessions** nav without stopping other sessions. Background runs continue when you switch workspace and return later.
- **New chat:** **Sessions** → **+ New Chat Session**; the center **Chat** tab shows the active session name.
- **Single chat surface** (no session tab strip). Archive, restore, or delete sessions from the Sessions list.
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
- After `lazbuild`, run [`scripts/post-build.sh`](scripts/post-build.sh) (or [`scripts/post-build.cmd`](scripts/post-build.cmd) on Windows) to copy `help/` and `assets/` next to the executable; when developing from the IDE, topics also resolve from the project `help/` folder.

### 7. Debugging mode and project rules
- **Debugging Mode** (Settings → Agent Behavior): when enabled, full tool JSON results appear in the chat history; when disabled, only tool errors are shown (successful tool calls stay hidden in chat).
- **Project Rules** (main menu → Workspace → Project Rules…): edit per-workspace Markdown files under `<workspace>/.rules/*.md`. Combined rule text is injected into the agent system prompt for Ask, Plan, and Agent modes.

### 8. Reserved Context & Instructions Panel
- Dedicated right-side panel for workspace guidelines, coding rules, and instructions context.

### 9. Utility panel (right)
- **Utility panel** with a `TPageControl`: Scratchpad, Execution Detail, and Plan.
- **Hidden by default**; toggle via **Window → Panels → Utility Panel**.

### 10. Integrated terminal (bottom panel)
- **View → Terminal** toggles a full-width bottom dock (above the status bar) with a real PTY shell (`$SHELL` / `/bin/bash` on Unix, `%COMSPEC%` on Windows).
- Terminal chrome is on the main form via **`TLcaTerminalPanel`** ([`LcaTerminalPanel.pas`](packages/LcaDesignSystem/src/LcaTerminalPanel.pas)); [`uTerminalPanel.pas`](uTerminalPanel.pas) is a thin alias type for app code.
- Docked height defaults to about **one quarter** of the client area (resizable splitter); floating window size is stored separately from docked height.
- When you open the panel with an active workspace, the shell starts in the **workspace root** (`pwd` / `cd`); switching workspaces restarts the shell in the new folder if the terminal is already visible.
- Powered by the [TerminalEmulator](https://github.com/andrewd207/TerminalEmulator) submodule (`third_party/TerminalEmulator`). **Windows** requires Windows 10 1809+ (ConPTY).
- **Linux PTY:** the embedded terminal needs `forkpty` from **libutil** (Debian/Ubuntu: `bsdutils` / `util-linux`). Build the submodule packages via `./scripts/build-terminal-deps.sh` before compiling the app. If the panel stays blank, check the status bar for a PTY error and verify `$SHELL` or `/bin/bash` exists.

#### Terminal manual test checklist

| Step | Linux / macOS | Windows |
|------|----------------|---------|
| View → Terminal shows bottom panel | `pwd` matches workspace | `cd` matches workspace |
| Resize splitter; restart app | Height restored | Height restored |
| Hide / show terminal & utility | Yes | Yes |
| Theme toggle | Colors readable | Colors readable |
| Interactive TUI | `ls` colors; optional `vim`/`nano` | `dir`, `git status` |

---

## Technology Stack

- [Free Pascal (FPC)](https://www.freepascal.org/)
- [Lazarus IDE](https://www.lazarus-ide.org/)
- Lazarus Component Library (LCL)
- Chat history, Markdown file preview, and Help topics use a **Markdown subset → HTML** renderer (`TMarkdownHtmlView` on streamed `TPanel` hosts; TurboPower IPro at runtime).

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

Install **terminal packages**, **LcaDesignSystem** runtime, and (for the Form Designer) the **LCA Design** palette once per machine:

**Linux / macOS:**

```bash
chmod +x scripts/install-lca-lazarus.sh
./scripts/install-lca-lazarus.sh
```

**Windows** (use `.cmd` if PowerShell blocks `.ps1` scripts):

```bat
scripts\install-lca-lazarus.bat
```

(Same as `install-lca-lazarus.cmd`.) Or: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-lca-lazarus.ps1`

**Close Lazarus** before running the full install: the script installs **`LcaDesignSystemDesign`** (palette only) and runs **`lazbuild --build-ide`**. The **runtime** `LcaDesignSystem` package is linked for builds but not embedded in `lazarus.exe`.

If Lazarus **hangs on startup** after an install, run **`scripts\recover-lazarus-ide.bat`**, then reinstall with **`install-lca-lazarus.bat`** (Lazarus closed). See [`packages/LcaDesignSystem/README.md`](packages/LcaDesignSystem/README.md).

Use **`--link-only`** for CI/headless builds without IDE palette install or IDE rebuild.

Legacy scripts [`scripts/build-terminal-deps.sh`](scripts/build-terminal-deps.sh) / [`.ps1`](scripts/build-terminal-deps.ps1) only link terminal packages; prefer `install-lca-lazarus.*`.

If `lazbuild` is not on `PATH`, set `$env:LAZBUILD` to your `lazbuild.exe` (for example `C:\lazarus\lazbuild.exe`).

**Form designer:** Chrome controls (`TLcaThemedPageTabBar`, `TLcaMarkdownView`, `TLcaTerminalPanel`, etc.) stream on **`mainunit.lfm`** from the **LCA Design** palette after running the install script. Regenerate the main shell with `python3 scripts/gen-main-lfm.py` when changing rail items or large structure. Edit forms from the **`.pas`** unit (**View → Toggle Form Unit** / F12).

Open `lazycodingagent.lpi` in Lazarus, or build from the command line:

**Linux / macOS:**

```bash
./scripts/install-lca-lazarus.sh --link-only
lazbuild lazycodingagent.lpi
./scripts/post-build.sh
```

On **Linux**, prefer the **Qt5** LCL widgetset in Lazarus (Project → Project Options → Compiler Options → Config and Target) so menubar and memo styling hooks in `LcaTheme` apply; GTK2/GTK3 are also supported with GTK menubar sync.

**Windows:**

```bat
scripts\install-lca-lazarus.cmd --link-only
lazbuild lazycodingagent.lpi
scripts\post-build.cmd
```

**CI:** GitHub Actions workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) runs the same flow on Linux, Windows, and macOS (headless `--link-only` install, no IDE palette rebuild).

**Manual IDE install:** compile `LcaDesignSystem.lpk` (runtime), then `LcaDesignSystemDesign.lpk` → **Use → Install** (after terminal packages). Do not install the runtime package into the IDE.

If the Lazarus IDE hangs when opening this project, use **`recover-lazarus-ide`**, or quit Lazarus and remove `lazycodingagent.lps` (session file), then open `lazycodingagent.lpi` again.

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
- `mainunit.pas` / `mainunit.lfm` — Main form: nav rail, nav body, center `TPageControl`, utility `TPageControl`, terminal view, menus, splitters, status bar
- `packages/LcaDesignSystem/` — **LcaDesignSystem** runtime package (`LcaTheme`, LCA palette components, Win32 paint helpers)
- `uTerminalPanel.pas` — Alias for `TLcaTerminalPanel` (PTY + `TTerminalLCLView` inside the design-system component)
- `uMainFileEditor.pas` — Single `TSynEdit` load/save/highlighter
- `uPlanView.pas` — Plan utility tab (path, build, memo)
- `third_party/TerminalEmulator/` — Git submodule: TerminalFramework + ViewLCL packages
- `uNavigationPanel.pas` — `TNavContentControl` binds to streamed nav controls on the main form
- `uChatPanel.pas` — Binds composer memos/combos/buttons; chat history on `TLcaMarkdownView`
- `packages/LcaDesignSystem/src/LcaMarkdownView.pas` — Markdown subset preview (TurboPower IPro) for chat, center preview, and Help
- `uPanelDetach.pas` — Detach navigation, chat, guidelines, utility, and terminal panels to floating windows
- `uThemeHooks.pas` — App hooks (SynEdit gutter); registers [`LcaThemeHooks`](packages/LcaDesignSystem/src/LcaThemeHooks.pas) for LCA components and terminal view
- `uChatSessionStore.pas` — Per-workspace JSON persistence for chat sessions (messages, archive flag)
- `uChatSessionHub.pas` — Per-workspace session hub: one `TAgentEngine` per session, parallel runs, save/shutdown
- `uWorkspaceState.pas` — State management and INI persistence for bounds, docking, modes, and themes
- `packages/LcaDesignSystem/src/LcaTheme.pas` — Dark/light design tokens, platform chrome (`ApplyPlatformChrome`), ComboBox/list owner-draw; on Windows, `LcaThemeWin32Buttons.pas` and `LcaThemeWin32ScrollBars.pas` custom-paint buttons and scrollbars
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
