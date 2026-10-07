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
- **Clean Minimalist Top**: Full vertical viewport space for navigation, chat, and guidelines panels, with comprehensive menu bar and status bar controls.
- Seamless Dark Mode default with instant Light Mode toggle via `View > Toggle Light / Dark Theme`.
- Clean splitters allowing custom width resizing between all panels.

### 3. Detachable Multi-Window Architecture
- Panels are docked to the main window by default and can be detached into independent, floating `TForm` windows.
- Floating windows can be moved to separate monitors across Windows, Linux, and macOS.
- Detached panels can be redocked with one click using the header `⇲ Dock` button or the `Window` menu.
- Panel visibility and floating window coordinates are persisted in configuration settings.

### 4. Vertical Navigation Rail & Panel
- Sleek 56px left navigation rail featuring top badge, tooltips, active indicator badges, and icons for:
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
- Model selector dropdown supporting `claude-3-7-sonnet`, `gpt-4o`, `deepseek-r1`, etc.

### 6. Reserved Context & Instructions Panel
- Dedicated right-side panel for workspace guidelines, coding rules, and instructions context.

---

## Technology Stack

- [Free Pascal (FPC)](https://www.freepascal.org/)
- [Lazarus IDE](https://www.lazarus-ide.org/)
- Lazarus Component Library (LCL)

---

## Building & Running

Open `lazycodingagent.lpi` in Lazarus or build directly using `lazbuild`:

```bash
lazbuild lazycodingagent.lpi
```

---

## Architecture & Unit Structure

- `lazycodingagent.lpr` — Application entry point
- `mainunit.pas` / `mainunit.lfm` — Main form designed with Lazarus Form Designer (`TForm1`), hosting menus, splitters, status bar, and dock hosts
- `uAppLogo.pas` — Vector brand drawing routines
- `uDockPanel.pas` — Custom-drawn dockable panel header with Detach/Dock and Hide controls, plus `TDetachedPanelForm` host for floating multi-monitor windows
- `uNavigationPanel.pas` — Custom painted navigation rail and content views
- `uChatPanel.pas` — Composer card, Ask/Plan/Agent mode dropdown selector, model selector, and message stream
- `uWorkspaceState.pas` — State management and INI persistence for bounds, docking, modes, and themes
- `uTheme.pas` — Dark/light design tokens, ComboBox custom owner-drawing styling, and recursive styling engine
- `uAppTypes.pas` — Shared enumerations, modes, and helpers
- `uMainWorkspace.pas` — Compatibility alias unit
