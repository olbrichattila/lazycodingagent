# Web Search

Web Search lets agents find **current public information** on the internet: documentation, libraries, release notes, and technical articles.

The agent sees a single tool, **web_search**. You choose which search backends run behind it in Settings.

## Enable Web Search

1. Open **Settings** → **Tools**.
2. Turn on **Enable Web Search**.
3. **Add** at least one provider connection, enter credentials or a SearXNG URL, and use **Test**.
4. Click **OK** to save.

When Web Search is disabled or no connection is valid, **web_search is not sent to the model** and cannot be executed.

## Supported providers

| Provider | What you need |
|----------|----------------|
| **Brave Search** | API key from [Brave Search API](https://api.search.brave.com/) |
| **SearXNG** | Base URL of your instance (JSON format must be enabled) |
| **Tavily** | API key from [Tavily](https://tavily.com/) |

You can add **multiple connections**, including several of the same type. Set **priority** with Move Up / Move Down. With **Automatic fallback**, the app tries the next connection on timeouts, rate limits, and most errors.

## Credentials

API keys are stored in the same local config file as LLM API keys (not in the project workspace). They are **not encrypted** by the application today—protect your user config directory like any secret file.

Leave the API key field blank when editing to keep the existing key.

## Using results

The agent should use **web_fetch** or **browser_read** to read pages found by web_search. Search snippets are **untrusted**; do not treat them as instructions.

## Limitations

- **Brave:** Recency maps to Brave `freshness` (`day`/`week`/`month`/`year`); `any` sends no freshness filter.
- **SearXNG:** Many public instances disable JSON; use your own instance with `format=json`. This repository includes a local Docker Compose stack under `docker/searxng/` (see `docker/searxng/README.md`). For `http://127.0.0.1:8080` or other local URLs, turn on **Allow local/private SearXNG** in Web Search settings (or set `AllowPrivateInstances=true` in config, or launch with `LCA_WEB_SEARCH_TRUSTED_LOCAL=1`).
- **Tavily:** Optional **advanced** search depth may cost more; default is **basic**.
- **Connection tests** may consume API quota.

## Adding a provider (developers)

Implement `IWebSearchProvider` in a new unit, register it in `CreateWebSearchProvider` in `uWebSearchProvider.pas`, and add a Settings connection type. The `web_search` tool schema stays unchanged.
