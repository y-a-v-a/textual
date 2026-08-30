# Textual upstream contribution tasks

Candidate contributions to [gonzalezreal/textual](https://github.com/gonzalezreal/textual), derived
from limitations Twain has worked around locally. Tracker reviewed 2026-07-18 against Textual 0.5.0
(all open + closed issues and PRs, plus keyword searches for "task list", "checkbox",
"ImageRenderer", "highlight"): **none of the tasks below are already filed or in flight.**

## Implementation status (2026-08-26)

All four tasks are implemented as a branch stack on top of
`perf/skip-unused-text-layout-readers`. Nothing is pushed yet.

| Task | Branch | Notes |
| --- | --- | --- |
| 1 | `fix/list-item-spacing-environment-updates` | Rebased onto the perf branch. Regression test verified: it fails on the unfixed `BlockVStack` and passes with the fix. |
| 2 | `feature/synchronous-syntax-highlighting` | Shipped as `.textual.syntaxHighlightingMode(.synchronous)`, **not** as an awaitable signal — see below. |
| 3 | `feature/task-list-rendering` | Detection at render time, on by default, styleable via `.textual.taskListMarker(_:)`. Unordered lists only. |
| 4 | `feature/text-run-effects` | Revival of PR #29 addressing all three review points; animation deliberately left out. |

Verified on macOS, iOS 26 simulator, and Mac Catalyst; the demo app builds on
macOS. tvOS/watchOS/visionOS were not verified — those SDKs are not installed
locally, so CI is the first place they get exercised.

### Task 2: the awaitable signal cannot work

Measured, not assumed. Under `ImageRenderer`, Textual draws **nothing at all** —
`StructuredText` and `InlineText` both render blank, because their content is
derived in an appearance callback that has not run by the time the drawing pass
happens. `.task` does fire, but its result never reaches the drawn output, so
there is no signal worth awaiting. That blank-render bug is the subject of open
upstream [PR #84](https://github.com/gonzalezreal/textual/pull/84) and was left
alone here.

Synchronous highlighting is therefore the only shape that fixes the problem, and
it does: in an offscreen window host, `.synchronous` produces coloured code on
the first drawn frame while the default produces none. Once #84 lands,
`ImageRenderer` should pick this up for free.

### Known gap in Task 3 — closed (2026-08-29)

An escaped marker (`- \[ ] text`) used to render a checkbox: Foundation's parser
produces the same literal text for the escaped and unescaped forms, so
render-time detection could not tell them apart. Fixed by consulting the source:
when the input contains `\[` or `\]`, the parser re-parses with
`appliesSourcePositionAttributes`, compares each run-leading `[` with its source
spelling, and tags escaped ones with the public `escapedTaskListMarker`
attribute (stripped source positions leave the output byte-identical to a plain
parse). Detection skips tagged runs. Zero cost for inputs without escapes.

---

## What the tracker review showed

Adjacent but distinct issues (do not confuse with the tasks below):

- [#6](https://github.com/gonzalezreal/textual/issues/6) — `blockSpacing` on the container is
  working-as-designed; must be set per block style. Not about live updates.
- [#45](https://github.com/gonzalezreal/textual/issues/45) — style modifier *ordering* after
  `structuredTextStyle` is ignored. Different bug from Task 1, though both live in style resolution.
- [#46](https://github.com/gonzalezreal/textual/issues/46) — `InlineStyle` modifiers replace whole
  property groups instead of merging. Related to theming ergonomics, not to Task 1.
- [#47](https://github.com/gonzalezreal/textual/issues/47) — re-parse performance when streaming
  markdown. Different from Task 2 (which is about *knowing when* async highlighting settled).

Maintainer signals worth pitching around (from closed feature PRs):

- **Scope**: Mermaid support ([PR #36](https://github.com/gonzalezreal/textual/pull/36)) was closed
  because Textual's core goal is native SwiftUI rendering with no web views. Stay native.
- **Bar for features**: TextRunEffect ([PR #29](https://github.com/gonzalezreal/textual/pull/29))
  got "I really like the idea" but was closed for API/test polish. Big-bang feature PRs stall;
  file an issue first, agree on API shape, keep the diff small, include visual-output tests.
- **Small fixes merge fast**: 0.5.0 merged four first-time contributors' patches (one-line to
  small fixes).

Suggested order: Task 1 (bug fix, small, easy win) → Task 2 (small API, strong story) →
Task 3 (feature) → Task 4 (only if reviving #29 appeals).

---

## Task 1 — Environment-driven block/list spacing doesn't react to environment changes

**Type**: bug fix · **Size**: small · **File an issue first**: yes (it's a clean bug report)

`StructuredText.BlockLayoutView` caches spacing in `@State` and only updates it inside
`onPreferenceChange(BlockSpacingKey.self)` (`Sources/Textual/Internal/StructuredText/BlockVStack.swift`,
`@State private var blockSpacing` + the `onPreferenceChange` closure). When an environment value
like `\.listItemSpacing` changes at runtime (e.g. `.textual.listItemSpacing(...)` driven by app
state), `resolvedListItemSpacing` changes in the environment but nothing re-runs the assignment —
the preference didn't change, so the stale cached value keeps being applied as the layout value.

**Twain's workaround** (delete once fixed upstream): keying the content subtree's identity on the
value so the whole tree rebuilds — `ContentView.swift:83` (`.id(theme.resolvedList.resolvedItemSpacing)`
next to `.id("content")`). Forcing identity loss is heavy: it tears down text-selection state and
re-runs syntax highlighting on every theme tick.

**Proposed fix**: make `BlockLayoutView` recompute when the environment inputs change — e.g. also
observe `resolvedListItemSpacing` / `listItemSpacingEnabled` with `onChange`, or drop the `@State`
cache and derive the layout value directly from (last preference value, environment overrides) so
environment changes flow through on their own.

**Test**: render a list, change `listItemSpacing` in the environment, assert measured layout height
changes (no view-identity reset). Repro project: any `StructuredText` list + a slider bound to
`.textual.listItemSpacing`.

---

## Task 2 — Deterministic "syntax highlighting settled" signal for offscreen rendering

**Type**: small API addition · **Size**: small–medium · **File an issue first**: yes

Textual tokenizes fenced code blocks in an async `.task`. Under `ImageRenderer` (PDF export,
snapshotting, printing) there is no way to know when highlighting has finished, so consumers must
guess with sleeps. Twain's `DocumentPrinter.swift:230-258` documents the dance: heuristic
`Task.sleep` waits scaled by document size, with the caveat that "stragglers in enormous documents"
may still print uncolored. Anyone exporting Textual content offscreen hits this.

**Proposed API** (pitch in the issue, let the maintainer pick the shape):

1. An awaitable — e.g. an async render preparation entry point, or an environment-exposed
   completion signal that resolves when all pending tokenization for the current content is done; or
2. A synchronous highlighting mode intended for offscreen/export contexts (highlight during parse
   instead of in a `.task`).

**Twain payoff**: replaces the sleep heuristics in `DocumentPrinter` with one `await`, and removes
a whole class of "code printed uncolored" regressions (see the print gotchas in `CLAUDE.md`).

**Test**: render markdown with a fenced block via `ImageRenderer` after awaiting the signal; assert
the drawn output contains more than one foreground color (Twain's
`printedCodeKeepsHighlightColorsWhenPrismIsAvailable` in `Tests/TwainTests/PrintTests.swift` is a
ready-made model, including the `PACKAGE_RESOURCE_BUNDLE_PATH` resource-bundle trick).

---

## Task 3 — GFM task list rendering (`- [ ]` / `- [x]`)

**Type**: feature · **Size**: medium · **File an issue first**: definitely (agree on API before code)

Textual has no task-list support (no hits in source for task lists/checkboxes). Task lists are core
GFM and ubiquitous in READMEs/TODOs, so this clears the "generally useful, native SwiftUI" bar in a
way Mermaid didn't.

**Prior art to reuse**: Twain preprocesses markers into glyphs before parsing — see
`Sources/Twain/TaskListMarkers.swift` for the edge cases already solved: markers in code blocks/inline code stay literal, uppercase `[X]`, empty
items, nested items, loose-item continuation paragraphs, markers outside lists.

**Proposed shape**: detection during parsing (Textual already has an
`AttributedStringMarkdownParser.SyntaxExtension` concept from
[PR #18](https://github.com/gonzalezreal/textual/pull/18) — a natural hook), plus rendering as a
non-interactive checkbox glyph (SF Symbols `square` / `checkmark.square`) in the list-item marker
position, ideally styleable via the existing list/item style system. Read-only display first —
interactive toggling is a separate, bigger discussion.

**Twain payoff**: delete the whole marker-expansion preprocessing layer and its test suite.

---

## Task 4 (optional) — Revive TextRunEffect as the vehicle for range highlighting

**Type**: feature revival · **Size**: large · **Only if you want a bigger project**

Twain's search feature paints match highlights with its own overlay machinery. Upstream,
[PR #29](https://github.com/gonzalezreal/textual/pull/29) proposed a `TextRunEffect` protocol
(custom `GraphicsContext` drawing per text run — highlights, custom underlines) and was closed
*with encouragement*: the maintainer liked the idea but wanted another pass on drawing order, how
broadly the renderer applies, and visual-output test coverage.

Reviving it means addressing that review feedback, not starting fresh — read the closed PR's
discussion first. A merged TextRunEffect would let Twain express search highlighting as an effect
over match ranges instead of maintaining overlay geometry. High effort, needs maintainer buy-in on
API; coordinate with the original author (@chihsuanwu) to avoid duplicated work.

---

## Process notes

- Fork as a **PR staging area only** — don't let Twain depend on the fork long-term. If Twain needs
  a fix before it's merged, point `Package.swift` at the fork branch temporarily and flip back to
  `from: "x.y.z"` once released.
- One branch per task, smallest possible diff, tests included (repo has CI across a platform
  matrix — see PR #66).
- The issue template asks for a vanilla-SwiftUI repro check, `main`-branch repro, and a
  duplicate-search checkbox — this file's tracker review covers the last one (as of 2026-07-18;
  re-check before filing).
