# Textual renderer performance analysis

Analyzed 2026-08-29 on the `feature/text-run-effects` stack (includes
`perf/skip-unused-text-layout-readers`). Grounded against upstream symptoms:
[#47](https://github.com/gonzalezreal/textual/issues/47) (streaming re-parse lag),
[#23](https://github.com/gonzalezreal/textual/issues/23) (freeze/crash at ~200+ blocks),
[#77](https://github.com/gonzalezreal/textual/issues/77) ("onChange(of: AnyTextLayoutCollection)
tried to update multiple times per frame").

## Implementation status (2026-08-30)

Six findings implemented on `feature/text-run-effects` (one commit each):

| Finding | Commit | Notes |
| --- | --- | --- |
| §2.1 origin-only invalidation storm | `6ccd402` | Origins adopted in place; materialized layouts survive reflow |
| §2.2 O(F²) `index(of:)` | `339248b` | Reverse map behind a derived-hash key (`Text.Layout` isn't Hashable) |
| §4.1 async tokenizer cache | `3175be7` | `CodeTokenCache` shared by both modes; cache hits skip the placeholder flash |
| §0/§2e GIF-frame attachment hashing | `4a4cbf6` | Custom `Image.hash` over first-frame identity, consistent with `==` |
| §1.2 blockRuns/inlineFeatures per body eval | `48cda68` | `Memo` @State cache; Table memoizes rows+columns together |
| §3 streaming re-parse | `0a2220b` | 50 ms leading-edge throttle; the incremental block parser remains open |

### Benchmark results (2026-08-30)

`Tests/TextualTests/Benchmarks/TextualBenchmarks.swift`, run with:

```
PACKAGE_RESOURCE_BUNDLE_PATH="$PWD/.build/arm64-apple-macosx/debug" \
  swift test --no-parallel --filter TextualBenchmarks
```

(That env var also fixes the 7 "environmental" highlighting test failures under plain
`swift test` — the resource bundle just isn't found without it.)

79 KB prose document (120 sections), macOS debug build, two runs per side.
Baseline = `bcd4a3c` (before the six fixes), fixed = `867c2a8`.

| Scenario | Baseline | Fixed | Change |
| --- | --- | --- | --- |
| initial-render (warm iters) | 1330–1439 ms | 1356–1459 ms | parity |
| initial-render, selection on | 1969–2316 ms | 2014–2278 ms | parity |
| streaming 80 chunks, feed | 10 895 / 10 958 ms | 662 / 659 ms | **16.6× faster** |
| streaming 80 chunks, total | 11 600 / 11 685 ms | 1378 / 1360 ms | **8.5× faster** |
| streaming 40 chunks of code, feed | 1078 ms | 359 ms | **3.0× faster** |
| spacing churn ×16 | 3061–3088 ms | 3115–3173 ms | parity |
| spacing churn ×16, selection on | 3837–3914 ms | 3862–3935 ms | parity |
| tokenizer, 40 snippets, 2nd pass | 9.4 / 9.8 ms | 0.3 / 0.4 ms | **~27× faster** |

Interpretation:
- **§3 throttle is the measured headline** — the streaming scenarios are upstream #47's
  exact shape and improve by an order of magnitude; initial render pays nothing.
- **§4.1 token cache** shows in the repeat-tokenization micro (~27×) and the code
  streaming feed (3×). Insight from the numbers: a warmed Prism call is sub-millisecond —
  the ~1.8 s first pass is bundle eval + JIT warm-up, i.e. the still-open §4.2 finding.
- **§2.1/§2.2 don't show here**: the harness drives no selection queries, and the
  discarded collections were lazy, so the baseline's rebuilds cost nothing until a
  hit-test follows a reflow. Measuring them needs real drag/hover events (Instruments on
  the demo app). The selection-enabled scenarios confirm no regression.
- **§1.2 memoization and §2e hashing** are below this harness's noise floor (churn is
  dominated by relayout; no animated images in the fixture). Parity confirms no
  regression.

Not yet done from the top tiers: the remaining §0 quick wins, §2.3 prefix sums,
§4.2 Prism off-main warm-up, §4.3 GIF timeline, §1.1 AnyView de-duplication, §1.3
intent-identity ForEach ids, and the benchmark harness.

---

**Vocabulary**: F = fragments (paragraph/list item/table cell), R = attributed runs,
L = wrapped lines. For a 91 KB README: F ≈ 10³, L ≈ 3·10³.

Costs fall into three multipliers, worst first:
1. **Per frame / per event** (selection, hover, GIFs) — §2, §5
2. **Per body evaluation** (every env change, every preference round-trip) — §1
3. **Per content change** (per streamed chunk → O(n²) over a stream) — §3

---

## §0 Quick wins — very low risk, do first

| Fix | Where |
| --- | --- |
| `static var` → `static let` for regex patterns (rebuilt per parser construction, i.e. per parent body eval) | `PatternTokenizer.swift:83-95`, `SyntaxExtension.swift:41` |
| Cache `InlineStyle.default` and style `@Entry` defaults in `static let` (each env read builds 5 existentials) | `InlineStyle+Default.swift:8`, `Style/ParagraphStyle.swift:20` + siblings |
| Reorder `Tuple(input, style, environment)` → cheap keys first so equality short-circuits before the O(block) string compare | `WithInlineStyle.swift:37` |
| Use `runs.first?.presentationIntent` (O(1)) instead of uniform-value `content.presentationIntent` (O(runs)) | `Paragraph.swift:30`, `Heading.swift:34`, `ThematicBreak.swift:30`, `CodeBlock.swift:40`, `MathBlock.swift:32`, `TableCell.swift:39` |
| Early-out `isMathBlock` before building the attachment `Set` (runs for every paragraph every body eval) | `Helpers/AttributedString.swift:4-17` |
| Skip `attachmentSizes(for:in:)` when `inlineFeatures()` reported no attachments | `TextBuilder.swift:27,141-163` |
| Explicit identity-based `hash(into:)`/`==` for `ImageAttachment`/`EmojiAttachment` — synthesized conformance hashes **every GIF frame** per fragment per body eval; `ImageResourceAttachment.swift:57-67` already has the right pattern | `ImageAttachment.swift:4`, `EmojiAttachment.swift:4`, `Image.swift:13-25` |
| Key highlighting `onChange` on a token generation counter, not the full `[CodeToken]` array (O(code length) compare per body eval) | `HighlightedTextFragment.swift:51` |
| `ImageLoader` NSCache: set `totalCostLimit` + per-entry `cost` (decoded frames currently resident forever) | `ImageLoader.swift:21,64` |
| Lazy `Formatter` in `TransferableText` (full bridge conversion at drag-start) | `TransferableText.swift:9-13` |
| Hoist `weight?.value` Mirror reflection out of per-resolve path | `TextStyleFontProvider.swift:44,54-58` |
| `hasText` → `layouts.contains { !$0.lines.isEmpty }` instead of materializing the whole document (currently: Mirror reflection per line + NSAttributedString join, triggered by **menu validation**) | `TextSelectionModel.swift:89-91`, `TextLayoutCollection+AttributedStringAccess.swift:5-7` |

---

## §1 Body-evaluation churn (paid on every env change / update pass)

### 1.1 `AnyView` at every block boundary defeats diffing
Every block is double-erased: config label (`BlockStyleConfiguration.swift:9` + siblings)
and resolved style (`Paragraph.swift:20`, `Heading.swift:23`, etc. — list items triple).
SwiftUI cannot structurally compare the subtree, so every block re-evaluates on every
update pass — which is what makes every other per-body-eval cost in this section
document-wide. Architectural cause: styles live in the environment as existentials.

Options: (a) erase once not twice (halve allocations, near-zero risk);
(b) `.equatable()` barrier on `Block` keyed on `(intent.identity, content hash)` —
big win, but under-keying risks stale rendering; (c) generic styles end-to-end
(breaking redesign, not worth it).

### 1.2 O(document) recomputation inside `body`
- `blockRuns(parent:)` recomputed per body eval at every nesting level — O(R × depth)
  (`BlockContent.swift:14`, `UnorderedList.swift:17`, `OrderedList.swift:25`,
  `Table.swift:45,51` — Table repeats per row, and again when the spacing preference
  lands). `intent(before:)` does a linear component scan per run
  (`Helpers/AttributedString.swift:163-179`). Fix: memoize in `@State` keyed on
  content (same pattern as `TextBuilder`), or compute the segmentation once at parse.
- `inlineFeatures()` runs in `TextFragment.init` — 3 attribute lookups × R per body
  eval of the parent (`TextFragment.swift:42`). The `TextBuilder` is guarded by
  `onChange(of: content)` (`:60`) but this isn't. Move it into the same `onChange`.
- `Heading` `.id(content.slugified())` — five string passes per heading per body eval,
  **and** a content-derived identity: while a heading streams in, its whole subtree
  (incl. state) is torn down per chunk (`Heading.swift:24`,
  `Helpers/AttributedString.swift:69-78`). Compute once at content change; consider a
  stable identity + separate anchor mechanism (anchor scrolling depends on the slug).
- `AttributedString(content)` copy per block per body eval just to satisfy
  `WithInlineStyle(input: AttributedString)` — also guarantees reference inequality so
  the O(n) Tuple compare never short-circuits (`Paragraph.swift:24`, `Heading.swift:28`,
  `TableCell.swift:33`, …). Fix: make `WithInlineStyle` generic over
  `some AttributedStringProtocol`, materialize inside resolve.
- Platform font lookups uncached: `preferredFontDescriptor` builds a fresh
  `UITraitCollection` per call (`PlatformFont.swift:26-34`), called several times per
  block per body eval via `FontScaled.resolve` (default paragraph style ×2, code block
  ×4). Fix: tiny fixed cache keyed `(textStyle, dynamicTypeSize, legibilityWeight) → CGFloat`.
- `TextFragment.text` re-applies `.customAttribute(TextFragmentAttribute())` per body
  eval, producing a fresh `Text` value (`TextFragment.swift:79-82`); apply once in
  `TextBuilder` and store the marked `Text`.

### 1.3 ForEach identity is positional
All block ForEach loops use `id: \.self` on indices (`BlockContent.swift:17`, lists,
tables). Any mid-document shape change (paragraph → fence while streaming) shifts every
later index → full identity loss: `@State`, `TextBuilder`, highlighting all rebuilt.
`PresentationIntent.IntentType.identity` is stable within a parse and currently unused —
use it as the ForEach id (fallback to index for nil intents). Not a total fix (reparse
renumbers on earlier-inserted blocks) but strictly better; pairs with the 1.1(b) barrier.

### 1.4 No laziness
`BlockVStack` uses `Group(subviews:)` — all 500 subtrees of a 500-block document are
built even if one screenful is visible (`BlockVStack.swift:23`). `LazyVStack` conflicts
with the margin-collapsing custom layout (`:68-145`). Genuine design tension; flagged,
not a quick fix.

### 1.5 Environment snapshot too wide
`TextEnvironmentValues` bundles 7 values; `WithInlineStyle` keys on all of them, so an
emoji-sizing change re-derives all inline styling document-wide
(`TextEnvironmentValues.swift:7-67`, `WithInlineStyle.swift:37`). Narrowing is
source-breaking (public type in protocol signatures) — note for a majorversion.

---

## §2 Selection / interaction subsystem (issues #77 and #23 live here)

### 2.1 Origin-only invalidation storm — highest-leverage single fix
`LiveTextLayoutCollection` equality compares `[AnchoredLayout]` **origins included**
(`LiveTextLayoutCollection.swift:15-17`). Any block resize / image load / reflow above
⇒ compare fails ⇒ per origin change: 3 × O(F) scans + 2 fresh F-element arrays
(`needsPositionReconciliation`, `LiveTextLayoutCollection.swift:21`;
`TextSelectionInteraction.swift:28`; `TextSelectionModel.swift:49`) — inside a view
update ⇒ the #77 "multiple times per frame" fault — and the materialized lazy layouts
(bounds/lines/runs/slices) are **discarded**, so every query below re-pays cold cost.

Fix: split identity from position. Compare `base.map(\.layout)` only (cache it);
refresh origins in place on the existing collection (make `origin` var, invalidate only
`bounds`), keeping materialized lines/runs/slices. Also drop the duplicated equality
check (view-level `onChange` + model-level guard do the same compare twice).

### 2.2 O(F²) per drag frame
`LiveTextLayoutCollection.index(of:)` is a linear scan with dynamic cast + layout
equality per element (`LiveTextLayoutCollection.swift:24-28`). Every
`AppKitTextSelectionView` (one per fragment) calls `selectionRects(for:layout:)` on
every `selectedRange` change ⇒ F × O(F) per drag mouse-move — 10⁶ compares on a
1000-fragment doc. Fix: reverse map built when `layouts` materializes, or plumb the
index down.

### 2.3 Full-document materialization from routine UITextInput traffic
`characterIndex(at:)` / `offset(from:to:)` / `position(from:offset:)` /
`stringLength` walk all layouts forcing `materializeContents()` — Mirror reflection
per line + NSAttributedString joins (`TextLayoutCollection+Positioning.swift:31-66`,
`Layout+Internals.swift:21-47`). One arrow key or handle drag = full-document
materialization. Fix: `lazy var cumulativeLengths: [Int]` prefix sums ⇒ O(1) lookups +
binary search; plus the cheap `hasText` from §0.

### 2.4 Hover path allocates per mouse-move
`url(for:)` at 60–120 Hz: forces bounds (O(F) warm, O(L) cold), then
`lines.flatMap(\.runs)` freshly allocates an existential array per event
(`TextLayoutCollection+Geometry.swift:5-20`, `TextLayoutCollection.swift:52-54`,
`AppKitTextSelectionInteraction.swift:31-33`). Fix: walk lines, filter by y, scan one
line's runs — zero alloc; cache last-hit rect and skip while inside it.

### 2.5 Hit-test scans
`layoutIndex(closestTo:)` linear over F forcing bounds
(`TextLayoutCollection+Geometry.swift:267-278`); during drag-autoscroll, §2.1 makes it
O(L) per frame. Fixing §2.1 restores the warm path; optionally add a minY-sorted binary
search (careful: table cells are side-by-side).

### 2.6 Disabled-selection residue
Per fragment even with selection off: 3 pass-through modifier nodes + a
`\.textSelection` env subscription (`TextFragment.swift:63-65`,
`TextSelectionBackground.swift:17`); `Overflow` emits `OverflowFrameKey` prefs nobody
reads (`Overflow.swift:82-90`). Gate on `\.textSelection` once at fragment level
(beware: structural `if` flips identity when selection toggles).

---

## §3 The streaming case (upstream #47) — the O(n²)

Parsing is correctly keyed on the markup string (`StructuredText.swift:125-134` — env
changes do NOT reparse; don't "fix" that). But per content change:
1. Full-document `AttributedString(markdown:)` synchronously on the main actor
   (`MarkupParser` is `@MainActor`), plus a full `PatternProcessor.expand` rebuild when
   extensions are on ⇒ quadratic over a stream.
2. New backing storage ⇒ nothing downstream compares equal ⇒ with §1.1, every block
   re-evaluates per chunk; `WithAttachments` `.task(id:)` restarts wholesale
   (`WithAttachments.swift:35`); async highlighting re-tokenizes (§4.1).
3. First frame renders empty (`onChange(initial:)` is an appearance callback) — same
   root cause as the ImageRenderer blank (upstream PR #84); every change is ≥2 full
   view-graph passes.

Fixes, independent and stackable:
- **Coalesce**: `.task(id: markup)` with a ~16–50 ms debounce ⇒ a burst of chunks =
  one parse. Cheap, big for streaming. Tradeoff: latency; pair with a synchronous
  first parse to avoid worsening the blank first frame.
- **Incremental block parsing**: split source into top-level block chunks, parse per
  chunk, LRU by chunk source; append reparses only the tail. Only fix that removes the
  O(n²). Real work: CommonMark-aware splitter (fences, lists, tables, setext, link
  refs span lines) + renumbering `IntentType.identity` across chunks.
- Then make unchanged blocks actually skip via §1.1(b) + §1.3.
- Correctness note found on the way: `onChange(of: markup)` ignores `parser` — changing
  baseURL/extensions alone keeps stale output. Fix after the regex `static let` change.
- Minor riders on the parse path: `EscapedTaskListMarkers.mayContain` = two O(n) scans
  per parse; `PatternTokenizer.tokenize` allocates a String per non-matching char
  (`PatternTokenizer.swift:30-70`) — track a pending Range instead.

---

## §4 Async work & caching

1. **Async tokenizer has no cache** — `CodeTokenizer` (default mode) is a bare actor;
   only the synchronous tokenizer has the 128-entry LRU
   (`CodeTokenizer.swift:12-27` vs `SynchronousCodeTokenizer.swift:16-51`). Every
   scroll-back / stream chunk = full JavaScriptCore round trip per code block. Fix:
   shared `(code, language) → [CodeToken]` store behind a lock, consulted by both.
2. **138 KB Prism bundle evaluates on the main thread** — `CodeTokenizer.shared` is a
   global `let` first touched from `@MainActor` (`HighlightedTextFragment.swift:88`),
   so disk read + full JS eval land on main at first code block, defeating the async
   mode's purpose. Warm from a detached task.
3. **GIFs tick at display rate** — `TimelineView(.animation)` fires at 60–120 Hz and
   rebuilds the Image per tick regardless of the GIF's own fps; each tick re-resolves
   the fragment's whole attachment Canvas; finished finite loops keep ticking forever
   (`ImageView.swift:33-39,70-77`). Fix: `.explicit(...)` fed from the already-built
   `Schedule.startTimes` (`:96-108`); freeze after final loop.
4. **Sync-highlight path does O(code) work per body eval even on cache hit** — string
   materialization + full-string hash + AttributedString rebuild
   (`HighlightedTextFragment.swift:66-74,107-133`) — exactly the repeated-render
   context it exists for. Cache the highlighted AttributedString keyed
   `(code, language, theme, env)`.
5. **No image downsampling** — `CGImageSourceCreateImageAtIndex` with nil options
   (`Image.swift:37,62-65`): a 4000×3000 image = ~48 MB resident, GPU-scaled per draw.
   Fix: `CGImageSourceCreateThumbnailAtIndex` + max pixel size (needs a policy for the
   ceiling; plumbing display width into the cache key hurts hit rate).
6. **swiftui-math (upstream dep)**: cache design is good, but its "read-write" lock
   only ever takes wrlock + copies the cache struct per access
   (`ReadWriteLockIsolated.swift:62-66`), and `sizeThatFits`/`baselineOffset` use
   different cache keys so both can typeset (`MathAttachment.swift:35-41`). Uncapped
   NSCaches keyed on resolved font size accumulate across dynamic-type changes.

---

## Already efficient — do not regress

- Conditional layout readers + geometry observer + plain-run coalescing (7459733).
- `LiveTextLayoutCollection`'s pervasive `lazy` materialization — preserve in any §2.1 fix.
- Parse keyed on markup via `onChange`, not per body eval; env changes don't reparse.
- `BlockRuns`/`AttributedSubstring` slicing copies no text.
- Tokenize/highlight separation: theme & dark-mode flips cost no JS.
- `ImageLoader`: actor + NSCache + in-flight dedup + `.returnCacheDataElseLoad`.
- Font provider Mirror-reflection cached (NSCache, 100); OS 26 native `Font.scaled(by:)`.
- Selection-rect building is single-pass with span merging; run-slice traversal is
  allocation-free; `CTRunGetStringIndicesPtr` zero-copy path.
- `Overflow` prunes its fragments from the root layout preference.
- `ResolvedXStyle` wrapper views are what make erased style bodies updatable — keep.
- Formatters are strictly off the render path (copy/export only), `blockNodes` lazy.
- `EscapedTaskListMarkers.mayContain` gating keeps escape handling off the common path.

---

## Suggested order of attack

1. §0 quick wins (one small PR-sized batch; zero behavioral risk).
2. §2.1 identity/origin split (fixes #77's fault, likely the #23 freeze mechanism, and
   converts §2.3/2.5 back to warm-cache costs) + §2.2 reverse map + §2.3 prefix sums.
3. §1.2 memoization batch (blockRuns / inlineFeatures / slugified / font cache) +
   §1.3 intent-identity ForEach ids.
4. §4.1/4.2 highlighter cache + off-main Prism warm-up; §4.3 GIF timeline.
5. §3 streaming: debounce first, incremental block parsing as the headline project.
6. §1.1 AnyView de-duplication, then (carefully) the Equatable block barrier.

## Measuring

No harness in-repo (the 7459733 numbers — 91 KB doc 2096→1112 ms, 274 KB 9560→4422 ms —
were ad hoc). Worth adding: an offscreen-window render timing test (the pattern from
`SyntaxHighlightingModeTests` works), a streaming simulation (append N chunks, measure
total + per-chunk), and Instruments' SwiftUI template (body-eval counts) on the demo app
with a large doc + selection enabled. Body-eval counts before/after are the honest
metric for §1; frame-time during drag-select for §2.
