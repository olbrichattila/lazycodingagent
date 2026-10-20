# 006 — Painted button

**Depends on:** [001](001-themed-control-base.md), [002](002-layout-metrics-tokens.md)

## Goal

Add **`TLcaPaintButton`** — fully custom-painted button (`TCustomControl` / `TLcaThemedControl`) with roles matching [`TLcaThemedButton`](../../../packages/LcaDesignSystem/src/LcaThemedButton.pas) (`TThemedButtonRole`), without Qt/GTK/Win32 native button styling paths.

## Scope

- Paint: fill, border, hover, pressed, disabled, focus ring (optional published flag).
- Caption from `Caption` property; keyboard focus and `Click` / `OnClick`.
- `ApplyTheme` + `ThemeKind` published.
- Register on palette; **do not** remove `TLcaThemedButton` yet.

## Out of scope

- Removing [`LcaThemedButtonPaint.pas`](../../../packages/LcaDesignSystem/src/LcaThemedButtonPaint.pas) or migrating main form buttons (step 012).
- Default/cancel form integration beyond standard `ModalResult` if needed for dialogs later.

## Touch list

- New `LcaPaintButton.pas`
- `LcaDesignSystem.lpk`, `LcaDesignReg.pas`

## Verification

1. Test form: primary, cancel, destructive, ghost roles in dark and light.
2. Compare approximate size to streamed `TLcaThemedButton` heights in chat footer (visual sanity only).
3. Linux Qt5 + Windows if available: same chrome geometry; no native theme leakage.

## Done when

`TLcaPaintButton` is usable on forms and theming is entirely under LCA paint code.
