# LazyCodingAgent

LazyCodingAgent is a cross-platform desktop AI coding assistant and editor built with Free Pascal and Lazarus (LCL). The goal is to provide a focused development environment inspired by tools such as Hermes, Cursor, and Codex.

> **Status:** Early project scaffold. The application currently contains the initial Lazarus application shell; the editor and AI-assisted workflows are planned for future development.

## Vision

LazyCodingAgent is intended to help developers understand, create, and modify software from one workspace. Planned capabilities include:

- AI-assisted coding, editing, and project exploration
- An integrated code editor and developer workspace
- Multiple detachable windows that can be moved across screens
- A modern dark-first interface with an optional light theme
- Cross-platform support for Windows, Linux, and macOS
- A workflow that keeps project context and coding tasks together

## Technology

- [Free Pascal](https://www.freepascal.org/)
- [Lazarus IDE](https://www.lazarus-ide.org/)
- Lazarus Component Library (LCL)

The project uses conditional platform initialization where needed and is intended to remain portable across supported Lazarus widgetsets.

## Building

Open `lazycodingagent.lpi` in Lazarus and build or run the project from the IDE. Alternatively, build it with the Lazarus command-line tools available in your environment:

```bash
lazbuild lazycodingagent.lpi
```

The generated executable and compiler output are platform- and configuration-dependent.

## Project layout

- `lazycodingagent.lpi` — Lazarus project file
- `lazycodingagent.lpr` — Free Pascal application entry point
- `mainunit.pas` / `mainunit.lfm` — initial main form
- `.rules/` — project development guidelines
- `backup/` — project backups

## Development principles

The project aims to follow these principles:

- Prefer single-responsibility components.
- Apply DRY (Don't Repeat Yourself) design.
- Keep the UI modern and dark-first while supporting a light mode.
- Design detachable windows to work across multiple monitors.
- Preserve portability across Windows, Linux, and macOS.

## Contributing

The project is at an early stage. Before making changes, inspect the existing Lazarus project and follow the guidelines in `.rules/`. Keep changes focused, portable, and compatible with the LCL.

## License

No license has been selected yet.
