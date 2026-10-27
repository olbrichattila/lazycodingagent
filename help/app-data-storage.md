# Application data storage

LazyCodingAgent keeps application settings and workspace registry in a SQLite database under your user config area.

## Location

On a typical Linux setup:

- Database: `~/.config/lazycodingagent/lazycodingagent/global.db`

The exact config root follows Lazarus `GetAppConfigDir` (under a `lazycodingagent/` subfolder).

## What is stored

- LLM provider settings and saved model lists
- Web search connection settings and API keys
- Browser automation preferences
- Workspace registry (list of workspaces and active workspace id)
- Panel layout and general application preferences

Chat sessions and syntax schemes may still use JSON files until later storage migrations.

## Secrets

API keys and similar secrets are encrypted in the database before they are written. This protects casual inspection of backup files; it does **not** stop someone who has both the application binary and your database file from recovering keys (the app embeds the decryption material).

## Recovery

If something goes wrong:

1. Quit LazyCodingAgent.
2. Restore `global.db` from a backup copy, or remove it to start with empty application settings (workspaces and chat sessions on disk are separate).
