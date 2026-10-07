# Workspace layout and panels

The main window is a dockable IDE-style layout: navigation on the left, chat in the center, optional side panels, and an optional bottom terminal.

## Navigation rail

The narrow left **activity bar** switches views:

- **Home** — workspace overview.
- **Projects** — file tree for the workspace.
- **Sessions** — chat session list (active and archived).
- **Bots** — agent presets and prompt setups.

Icons are tooltipped; the active item is highlighted.

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
