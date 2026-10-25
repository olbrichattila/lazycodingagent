# Browser automation

Lazy Coding Agent drives a **headless Chromium** (Chrome, Chromium, or Edge) through the Chrome DevTools Protocol (CDP). Use it to verify web apps you build in the workspace.

## Setup

1. Install a Chromium-compatible browser (Google Chrome, Chromium, or Edge).
2. Set **Settings → Agent → Chromium executable** if auto-discovery fails. On Linux, if `/usr/bin/google-chrome` is a wrapper script, try `/opt/google/chrome/google-chrome` explicitly.
3. For **localhost** dev servers, enable browser localhost permission for the chat session (stored in session metadata as `allowBrowserLocalhost`).
4. For **clicks and form fills**, enable interactive browser permission (`allowBrowserInteractive`).

## Workflow example

1. Start your dev server with `shell` (Agent mode).
2. `browser_navigate` to `http://127.0.0.1:3000/` (with localhost allowed).
3. `browser_inspect` to find selectors or `ref` values.
4. `browser_fill` / `browser_click` / `browser_wait`.
5. `browser_console` and `browser_network` for failures.
6. `browser_screenshot` for visual evidence (saved under `.lca/artifacts/`).
7. `browser_close` when finished.

## Screenshots and models

Screenshot tools return `artifact_path` in JSON. Image-capable models may receive the attachment on the tool result; text-only models should read the path.

## Troubleshooting

- **BROWSER_NOT_FOUND** — Install Chrome/Chromium/Edge or set the executable path.
- **CDP_CONNECTION_FAILED** — Headless Chrome started but the app could not open the DevTools WebSocket (message may include details such as `Sec-WebSocket-Accept mismatch` or `TCP connect failed`). Check: browser runs from a terminal (`google-chrome --headless=new --remote-debugging-port=9222 --remote-allow-origins=* about:blank` then `curl http://127.0.0.1:9222/json/version`); set the real binary in Settings (not a distro wrapper); avoid Snap-only Chromium unless it supports remote debugging.
- **ACCESS_DENIED** — URL blocked (private network) or localhost/interactive permission missing.
- **SESSION_NOT_FOUND** — Wrong `session_id` or session idle-timed out; navigate again.
- **AMBIGUOUS_SELECTOR** — CSS matched multiple elements; narrow the selector.
