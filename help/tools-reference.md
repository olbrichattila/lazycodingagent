# Agent tools reference

Tools are functions the LLM can call with **JSON arguments**. Results are returned as JSON strings (errors include an `error` field). Only **advertised** tools are sent to the model for a given mode.

Aliases: `search_code` also answers to `grep`; `shell` to `terminal` / `run_process`; `todo` to `plan`.

## Mode summary

| Capability | Ask | Plan | Agent |
|------------|-----|------|-------|
| Read/search/list/glob/git/diagnostics/web_fetch/browser_read | Yes | Yes | Yes |
| todo (session task list) | Yes | Yes | Yes |
| create_plan_file | No | Yes | Yes |
| write_file, apply_patch, edit_file, shell | No | No | Yes |

## Path rules

- **Read/search tools** may target paths outside the workspace (absolute paths or `..` segments are allowed after canonicalization).
- **Write tools and shell `cwd`** default to the workspace root only. Per chat session, enable **Allow modify outside the working directory** to lift that write sandbox.
- **create_plan_file** and chat image attachments always stay under the workspace (`.plan/` and `.lca/attachments/`).

## Tools

### read_file

Read text from a file with optional line offset and limit (large file and line caps apply).

**Modes:** Ask, Plan, Agent.

### write_file

Write or overwrite a file; creates parent directories as needed.

**Modes:** Agent only.

### list_directory

List immediate children of a directory (sorted, capped entry count).

**Modes:** Ask, Plan, Agent.

### glob

Find paths matching a wildcard pattern (`*`, `?`, `**`). Use `/` in patterns. On Windows and macOS, matching is case-insensitive; on Linux it is case-sensitive.

**Modes:** Ask, Plan, Agent.

### search_code

Search file contents (literal or regex, optional path glob). Skips files larger than 16 MiB and extremely long lines. Alias: `grep`.

**Modes:** Ask, Plan, Agent.

### apply_patch

Apply a **unified diff** after validation (create, modify, delete files). On success, the JSON may include a `warnings` array when the tool corrected minor format issues (for example wrong `@@` line counts).

**Modes:** Agent only.

#### Patch format pitfalls

- One-line change: `@@ -N,1 +N,1 @@` then exactly one `-` line and one `+` line (`N` is the 1-based line number from `read_file`).
- The number after the comma in `@@ -start,count` is how many old-side hunk lines follow (` ` context and `-` removals), not “lines start through end.”
- Failures return `error_kind` such as `context_mismatch`, `invalid_hunk`, `incomplete_hunk`, or `hunk_count_mismatch`; many errors include a `hint` field.

### edit_file

Replace **exactly one** occurrence of `old_text` with `new_text` in a file (strict byte match). Use for a single substitution when a unified diff is awkward.

**Modes:** Agent only.

### shell

Run a shell command in the project directory with timeout limits (Unix: `/bin/sh -c`; Windows: `cmd.exe /C`).

**Modes:** Agent only.

### diagnostics

Read cached compiler/linter output; in Agent mode can run a build/check and refresh the cache. Auto-detected builds (`Cargo.toml`, `package.json`, `Makefile`, and similar) run with the working directory set to the directory that contains the manifest, not always the workspace root.

**Modes:** Ask, Plan, Agent (build side effects in Agent).

### git

Inspect repository: status, diff, log, or show. **No commits or pushes.**

**Modes:** Ask, Plan, Agent.

### todo

Read or replace a **session-local** task list (pending / in_progress / completed). Alias: `plan`.

**Modes:** Ask, Plan, Agent.

### create_plan_file

Save plan markdown under `<workspace>/.plan/plan-*.md`.

**Modes:** Plan, Agent.

### web_fetch

Fetch and extract readable content from a **public** `http` or `https` URL (documentation sites, articles, raw GitHub pages, and similar). Returns JSON with `content` (markdown by default), optional `title`, `content_type`, `http_status`, and `truncated`.

**Parameters:** `url` (required); `format` — `markdown` (default), `text`, or `html`; `max_length` — default 20000 characters.

**Modes:** Ask, Plan, Agent.

**Security:** Only public destinations; loopback, private networks, link-local addresses, and URLs with embedded credentials are blocked. Redirects are followed manually (up to 5) with re-validation. Response bodies are capped at 5 MiB; connect timeout 10s, overall 30s. No cookies or auth headers are sent.

**Platforms:** Windows uses system TLS (Schannel). Linux, macOS, and Raspberry Pi use OpenSSL (same requirement as HTTPS in Settings).

**Limits:** JavaScript-rendered pages may appear empty or incomplete; PDF and binary types return `unsupported_content_type`. Fetched page text is **untrusted** — the agent must not treat it as instructions.

Prefer `web_fetch` over `shell`/`curl` for reading websites.

### browser_read

Open a **public** `http` or `https` URL in a headless Chromium-compatible browser (Chrome, Chromium, or Edge), wait for rendering, and extract readable content. Use when `web_fetch` returns an empty or incomplete JavaScript application shell.

**Parameters:** `url` (required); `format` — `markdown` (default), `text`, or `html`; `wait_strategy` — `domcontentloaded`, `load` (default), or `selector`; `wait_selector` — required when `wait_strategy` is `selector`; `timeout_ms` (default 30000); `max_length` (default 20000).

**Modes:** Ask, Plan, Agent.

**Requirements:** A Chromium-compatible browser installed on the system, or a custom path set under **Settings → Agent → Chromium executable**.

**Security:** Same public-destination rules as `web_fetch` (no loopback, private networks, or embedded credentials). Subresource requests are filtered during browsing. Page content is **untrusted**.

**Limits:** One browser session per tool call; no screenshots or interactive automation yet. Localhost/dev-server browsing is not enabled in production.

Prefer `web_fetch` first; use `browser_read` only when JavaScript rendering is needed.

## Educational note

When you add or change tools in code (`uAgentTools.pas` and `uTool*.pas`), update this help page and **How the agent works** so learners stay aligned with the real behavior.
