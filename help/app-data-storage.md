# Application data storage

LazyCodingAgent keeps application settings and workspace registry in a SQLite database under your user config area, not in a plain `config.ini` in the project folder.

## Location

On a typical Linux setup:

- Database: `~/.config/lazycodingagent/lazycodingagent/global.db`
- Legacy backups (after first-run migration): `config.ini.bak.*` and `workspaces.json.bak.*` beside the old paths

The exact config root follows Lazarus `GetAppConfigDir` (same family of paths as the old `config.ini`).

## What is stored

- LLM provider settings and saved model lists
- Web search connection settings and API keys
- Browser automation preferences
- Workspace registry (list of workspaces and active workspace id)
- Panel layout and general application preferences

Chat sessions and syntax schemes may still use JSON files until later storage migrations.

## Secrets

API keys and similar secrets are encrypted in the database before they are written. This protects casual inspection of backup files; it does **not** stop someone who has both the application binary and your database file from recovering keys (the app embeds the decryption material).

## Legacy import

On first launch after an upgrade, if a legacy `config.ini` or `workspaces.json` is found, the app imports into `global.db` and renames the old files with a `.bak.<timestamp>` suffix.

To force the old INI/JSON readers for troubleshooting, set environment variable `LAZYCODINGAGENT_LEGACY_STORAGE=1` and restart the app.

## Recovery

If something goes wrong:

1. Quit LazyCodingAgent.
2. Rename or remove `global.db`.
3. Restore legacy files from `.bak.*` backups (remove the `.bak.<timestamp>` suffix).
4. Start the app again (or use `LAZYCODINGAGENT_LEGACY_STORAGE=1` while diagnosing).
