# m1-read-through-syntax-schemes — Syntax scheme repository

**Status:** Not started

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Out of scope

- Seeding built-in generic scheme via migration only (can be part of this or M2 import).
- Dropping per-file `syntax-schemes/` directory (M3 / §6.5).

## Goal

`ISyntaxSchemeRepository` + SQLite adapter. `uSyntaxSchemeRegistry.pas`: if `syntax_schemes` empty, load index + files; on save, write `json_body` to global DB (§6.5).

## Deliverables

- Interface + `uSqliteSyntaxSchemeRepository.pas`.
- Integration in `uSyntaxSchemeRegistry.pas`.

## Acceptance criteria

- [ ] Custom schemes round-trip through SQLite after edit/save.
- [ ] Built-in schemes identifiable (`built_in` flag).
- [ ] Empty DB + legacy files → same editor behavior as today.

## References

- Parent §5.1 `syntax_schemes`, §6.5, `uSyntaxSchemeRegistry.pas`
