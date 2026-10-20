# 012 — App migration and docs

**Depends on:** [003](003-paint-surface.md) through [011](011-painted-nav-list.md)

## Goal

Incrementally migrate **pilot** UI on the main form to painted components where ready, and document the **native island** policy (editor, terminal, prompt memo).

## Scope

- [`mainunit.lfm`](../../../mainunit.lfm) / helpers: swap selected controls (e.g. surfaces, nav rail, buttons, combos, lists, markdown host) per prior steps—**minimal diff**, designer-owned layout.
- Update [`packages/LcaDesignSystem/README.md`](../../../packages/LcaDesignSystem/README.md) palette table for new types.
- User help per workspace rule: [`help/index.json`](../../../help/index.json) and relevant topics (e.g. UI/overview) — note painted chrome vs native editor/terminal.
- README cross-platform note: painted scrollbars/chrome; Qt5 Linux recommended.

## Out of scope

- `TSynEdit`, `TLcaTerminalPanel`, `memChatPrompt` replacement.
- Removing legacy `TLcaThemedButton` / `TLcaSurfacePanel` unless all call sites migrated.

## Touch list

- `mainunit.lfm`, `uChatPanel.pas`, `uNavigationPanel.pas` (as needed)
- `packages/LcaDesignSystem/README.md`
- `help/*.md`, `help/index.json`

## Verification

1. `lazbuild --widgetset=qt5 lazycodingagent.lpi` succeeds.
2. Full manual pass: nav, chat scroll, composer combos/buttons, utility tabs, theme toggle, resize, detach panels if used.
3. Help menu: new/updated topic renders in preview.
4. No `ChangeBounds loop detected` during normal use.

## Done when

Main app uses painted stack for agreed pilot areas; docs describe what remains native and how delivery gates worked on `feature/lca-painted-controls`.
