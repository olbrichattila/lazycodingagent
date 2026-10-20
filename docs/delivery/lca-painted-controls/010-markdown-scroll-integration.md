# 010 — Markdown scroll integration

**Depends on:** [005 — Scroll host](005-scroll-host.md)

## Goal

Integrate [`TLcaMarkdownView`](../../../packages/LcaDesignSystem/src/LcaMarkdownView.pas) with **`TLcaScrollHost`**: `TIpHtmlPanel` inside the host, **native scrollbars off**, scrolling via LCA-painted bars.

## Scope

- Refactor internal structure: markdown host parent becomes scroll host (or wraps viewer).
- Preserve `SetMarkdown`, `SetHtmlBody`, `ApplyTheme`, deferred render/scroll-to-end behavior.
- Keep TurboPower IPro dependency; no new markdown engine.
- `WrapThemedHtmlDocument` CSS may adjust margins if viewport width changes.

## Out of scope

- Custom markdown layout without HTML.
- Chat panel wiring changes beyond what `TLcaMarkdownView` encapsulates.

## Touch list

- `packages/LcaDesignSystem/src/LcaMarkdownView.pas`
- `LcaScrollHost.pas`

## Verification

1. Open chat or test harness: long history scrolls with LCA scrollbars (not OS-themed bars on Linux).
2. Scroll-to-end after new message still works.
3. Dark/light on markdown content; resize chat panel.
4. Select/copy text in viewer if previously supported.

## Done when

Markdown view scrolling is visually consistent across platforms via `TLcaScrollHost`.
