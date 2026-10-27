# m2-importer-syntax-schemes — Syntax schemes import

**Status:** Not started

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Out of scope

- Deleting `syntax-schemes/` directory (M3).

## Goal

Import `syntax-schemes.json` (and referenced bodies) into `syntax_schemes` with `json_body`, `built_in`, `updated_at` per §6.5.

## Deliverables

- Importer unit; seed built-in generic scheme if missing.

## Acceptance criteria

- [ ] All custom schemes from fixture appear in DB.
- [ ] Built-in flag set correctly for shipped schemes.
- [ ] Idempotent re-import.

## References

- Parent §6.5, `uSyntaxSchemeRegistry.pas`
