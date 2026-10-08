# Agent tools reference

Tools are functions the LLM can call with **JSON arguments**. Results are returned as JSON strings (errors include an `error` field). Only **advertised** tools are sent to the model for a given mode.

Aliases: `search_code` also answers to `grep`; `shell` to `terminal` / `run_process`; `todo` to `plan`.

## Mode summary

| Capability | Ask | Plan | Agent |
|------------|-----|------|-------|
| Read/search/list/glob/git/diagnostics read | Yes | Yes | Yes |
| todo (session task list) | Yes | Yes | Yes |
| create_plan_file | No | Yes | Yes |
| write_file, apply_patch, edit_file, shell | No | No | Yes |

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

Find paths matching a wildcard pattern (`*`, `?`, `**`).

**Modes:** Ask, Plan, Agent.

### search_code

Search file contents (literal or regex, optional path glob). Alias: `grep`.

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

Read cached compiler/linter output; in Agent mode can run a build/check and refresh the cache.

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

## Educational note

When you add or change tools in code (`uAgentTools.pas` and `uTool*.pas`), update this help page and **How the agent works** so learners stay aligned with the real behavior.
