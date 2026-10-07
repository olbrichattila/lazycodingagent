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
- **Complete Dark & Light Tab Pages Styling**: All `TPageControl` tab strips, active indicators, and `TTabSheet` pages (including Settings dialog and Utility panel) follow the theme seamlessly with custom owner-drawing and cohesive high-contrast styling across Windows, Linux, and macOS.
- **TLazyTabControl Custom Component**: Robust custom tab control (`TLazyTabControl` and `TLazyTabPage`) with native LCL client area adjustment (`AdjustClientRect`), component streaming protection (`Loaded`), tab close callbacks, badge notifications, and zero `ChangeBounds` loop cycles.
- **Clean Minimalist Top**: Full vertical viewport space for navigation, chat, and guidelines panels, with comprehensive menu bar and status bar controls.
- Seamless Dark Mode default with instant Light Mode toggle via `View > Toggle Light / Dark Theme`.
- **Icon-only navigation rail** (VS Code–style activity bar) with accent-blue active icon and left indicator; tooltips on hover.
- **Accent text selection** on chat and navigation lists (owner-drawn rows — blue text, no OS highlight band).
- **Cross-platform role buttons** (`TThemedButton` in `uThemedButton.pas`): accent primary, outlined Cancel (`BorderStrong` / `Border`), and destructive Stop — same painted look on Windows, Linux (GTK), and macOS (Cocoa).
- **Cross-platform UI**: icon-only nav rail, owner-draw list accent selection, and theme tokens apply on all LCL targets.
- **Scrollbars / title chrome**: on **Windows**, `ApplyPlatformChrome` uses immersive dark mode and `DarkMode_Explorer` for native scrollbars; on **Linux and macOS**, scrollbars and window chrome follow the **OS widget theme** (align the system GTK/Cocoa dark mode with the in-app dark theme for best results).
- Clean splitters allowing custom width resizing between all panels.

#### Platform verification checklist

| Check | Windows | Linux (GTK) | macOS (Cocoa) |
|-------|---------|-------------|---------------|
| Nav rail icons + accent selection | Yes | Yes | Yes |
| List rows: accent text, no blue band | Yes | Yes | Yes |
| Primary / Cancel / Stop buttons (`TThemedButton`) | Yes | Yes | Yes |
| Dark scrollbars matching app surface | Themed via Win32 | OS GTK theme | OS AppKit theme |
| Light/dark toggle coherent | Yes | Yes | Yes |

### 3. Detachable Multi-Window Architecture
- Panels are docked to the main window by default and can be detached into independent, floating `TForm` windows.
- Floating windows can be moved to separate monitors across Windows, Linux, and macOS.
- Detached panels can be redocked with one click using the header `⇲ Dock` button or the `Window` menu.
- Panel visibility and floating window coordinates are persisted in configuration settings.

### 4. Vertical Navigation Rail & Panel
- Sleek 56px left navigation rail with logo, icon-only slots, tooltips, and accent active indicator for:
  - **⌂ Home**: Workspace dashboard and overview.
  - **◫ Projects**: Project explorer and file tree.
  - **💬 Sessions**: Active conversations and chat history.
  - **⚡ Bots**: Custom coding agents and prompt setups.
- Connected content area with contextual actions for the active navigation selection.

### 5. Primary AI Agent & Chat Workspace
- Clean hero greeting: `What should we build in <project name>?`.
- Embedded workspace badge and live conversation history stream.
- Multiline prompt composer with mode dropdown selector:
  - **Ask**: Fast Q&A without direct workspace mutations.
  - **Plan**: Architecture design, checklists, and specs.
  - **Agent** (*Default*): Full autopilot coding and editing.
- Instant mode and model switching synced with application state and status bar.
- Model selector dropdown supporting `anthropic/claude-3.7-sonnet`, `Hermes-4-70B`, `Hermes-4-405B` (Nous Research), `openai/gpt-4o`, `deepseek/deepseek-r1`, etc. (OpenRouter slugs where noted).

### 6. Debugging mode and project rules
- **Debugging Mode** (Settings → Agent Behavior): when enabled, full tool JSON results appear in the chat history; when disabled, only tool errors are shown (successful tool calls stay hidden in chat).
- **Project Rules** (main menu → Workspace → Project Rules…): edit per-workspace Markdown files under `<workspace>/.rules/*.md`. Combined rule text is injected into the agent system prompt for Ask, Plan, and Agent modes.

### 7. Reserved Context & Instructions Panel
- Dedicated right-side panel for workspace guidelines, coding rules, and instructions context.

### 8. Detachable Utility / Blank TabPage Panel (Right Corner)
- Extra right-corner panel hosting a clean `TPageControl` with an initial blank tab sheet (`FTabSheetBlank`).
- **Invisible by default**: Starts hidden to keep the workspace streamlined and distraction-free.
- **Toggleable & Detachable**: Can be toggled on/off at any time via `Window > Panels > Utility Panel` or detached to a floating multi-monitor window via `Window > Detach Utility Panel to Window` or panel header icon.

---

## Technology Stack

- [Free Pascal (FPC)](https://www.freepascal.org/)
- [Lazarus IDE](https://www.lazarus-ide.org/)
- Lazarus Component Library (LCL)
- **TurboPowerIPro** (Lazarus package; IpHtml markdown chat transcript in `uMarkdownView.pas`)

---

## Building & Running

Open `lazycodingagent.lpi` in Lazarus or build directly using `lazbuild`:

```bash
lazbuild lazycodingagent.lpi
```

### HTTPS for LLM providers (Fetch Models, chat, agent)

All HTTPS traffic goes through [`uLlmClient.pas`](uLlmClient.pas) (Settings **Fetch Models**, agent completions).

| Platform | Transport | Notes |
|----------|-----------|--------|
| **Windows** | WinHTTP + Schannel ([`uWindowsHTTP.pas`](uWindowsHTTP.pas)) | No OpenSSL DLLs beside the exe |
| **Linux / macOS** | `fphttpclient` + `opensslsockets` | System OpenSSL must be installed and visible to FPC (typical Lazarus Linux builds; on macOS often Homebrew `openssl@3` or system libs) |

If Fetch Models or chat fails with an OpenSSL initialization error on Linux/macOS, install SSL development libraries for your distro and ensure Lazarus was built with SSL support. The app surfaces a dialog instead of crashing when SSL is unavailable.

---

## Architecture & Unit Structure

- `lazycodingagent.lpr` — Application entry point
- `mainunit.pas` / `mainunit.lfm` — Main form designed with Lazarus Form Designer (`TLazyCodingAgentForm`), hosting menus, splitters, status bar, and dock hosts
- `uAppLogo.pas` — Vector brand drawing routines
- `uDockPanel.pas` — Custom-drawn dockable panel header with Detach/Dock and Hide controls, plus `TDetachedPanelForm` host for floating multi-monitor windows
- `uNavigationPanel.pas` — Custom painted navigation rail and content views
- `uChatPanel.pas` — Composer card, Ask/Plan/Agent mode dropdown selector, model selector, and markdown message stream
- `uMarkdownView.pas` — Theme-aware markdown → HTML renderer (`TIpHtmlPanel`) with auto-scroll-to-bottom
- `uWorkspaceState.pas` — State management and INI persistence for bounds, docking, modes, and themes
- `uTheme.pas` — Dark/light design tokens, platform chrome helpers (`ApplyPlatformChrome`), ComboBox/list owner-draw, and recursive styling
- `uThemedButton.pas` — Cross-platform painted primary, cancel (outline), and destructive buttons
- `uCustomTabControl.pas` — Modern custom tab control (`TLazyTabControl`) and tab pages (`TLazyTabPage`) with theme rendering, close badges, and LCL alignment integration
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
- `uToolApplyPatch.pas` / `uToolEditFile.pas` — `apply_patch` unified diff and hidden `edit_file`
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

Advertised tools: `read_file`, `write_file`, `list_directory`, `glob`, `search_code`, `apply_patch`, `shell`, `diagnostics`, `git`, `todo`, `create_plan_file`.

Tool messages returned to the LLM are **JSON strings**. Failures include an `error` field; patch failures often add `error_kind` (`context_mismatch`, `format`, `hunk_count_mismatch`, `incomplete_hunk`, `invalid_hunk`, `empty_patch`, `patch_apply`), plus optional `path`, `line`, and `partial` when a multi-file patch stops mid-batch.

| Mode | Write / shell / patch | Plan files |
|------|------------------------|------------|
| Ask | Blocked | Blocked |
| Plan | Blocked | `create_plan_file` allowed |
| Agent | Full mutating set | Allowed |

### Running tool integration tests

Requires FPC, Lazarus `lazutils` on the unit path, and Python 3:

```bat
tests\run_tests.bat
```

```bash
tests/run_tests.sh
```

Builds `tests/tool_driver.lpr` and runs `tests/test_local_tools.py` (patch, path sandbox, shell, diagnostics fixtures ported from lazcodingagent).
