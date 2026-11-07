# Text selection on macOS only selects one word

Reported 2026-11-05 from Twain (a read-only Markdown viewer built on this fork, pinned at
`b6f4c93`).

## Reported behaviour

In a rendered Markdown document in Twain, selection never gets past a single word.
Selecting a phrase, a sentence or several paragraphs doesn't work.

Still unknown, and needed to narrow it down:

1. Does click-and-drag highlight nothing at all, or does the highlight stop at one word?
2. Does a double-click select a word, and does Shift+→ then extend the selection?
3. Does ⌘A select the whole document?
4. Does it happen in every document, or only in some, such as ones with math or code blocks?

## Why this belongs in Textual, not Twain

Twain's only part in selection is `.textual.textSelection(.enabled)` on the document view
(`Twain/Sources/Twain/ContentView.swift`). Textual's `NSTextInteractionView`
(`Sources/Textual/Internal/TextInteraction/AppKit/NSTextInteractionView.swift`) does all the
mouse work:

| Gesture | Effect |
|---|---|
| single click | resets the selection and sets `dragStart` |
| double-click | selects the word (`wordRange`) |
| triple-click | selects the block (`blockRange`) |
| drag | `TextRange(from: dragStart, to: closestPosition)` |

Twain has no gesture recognizers, event monitors, window background dragging or
`acceptsFirstMouse` changes that could intercept mouse events.

## In-process probe

Synthetic clicks (`CGEvent` posts) are blocked on the dev machine, because the terminal has no
Accessibility permission. Instead, a throwaway Swift Testing test in Twain did the following:

1. Hosted a view in an `NSWindow` through `NSHostingView` and let it lay out for 1.5 seconds.
2. Found the `NSTextInteractionView` by its class name.
3. Sent it mouse events.
4. Read the selection back by calling its `copy:` action and reading `NSPasteboard.general`.

It ran on three setups, all inside a `ScrollView`, using a heading followed by two paragraphs.

### Results when events are sent to the view directly

The probe called `mouseDown`, `mouseDragged` and `mouseUp` on the view itself:

| Setup | ⌘A (`selectAll:`) | Double-click | Drag across two paragraphs |
|---|---|---|---|
| Plain `StructuredText(markdown:)` with `.textual.textSelection(.enabled)` | whole text ✓ | one word ✓ | whole span ✓ |
| Twain's `DocumentText`: two `StructuredText`s for front matter and body, themed style | whole text ✓ | one word ✓ | whole span ✓ |
| Twain's full `ContentView` | whole text ✓ | one word ✓ | whole span ✓ |

The selection model, `closestPosition` and the drag logic all work in Twain's exact view
setup. Twain's view tree doesn't break selection once the events arrive.

### Results when events go through `NSWindow.sendEvent`

- Double-click events reached the view and selected a word.
- Single-click `leftMouseDown` events never reached `mouseDown`. Even the reset on mouse-down
  didn't happen, because the earlier word selection was still there afterwards.
- So the drags that followed did nothing. This was the same in plain Textual and in Twain.

This result is **inconclusive**. The test runner can't become the active app
(`isKeyWindow` stays `false` even after `NSApp.activate`). A non-key window swallows the
first single click unless the view returns `true` from `acceptsFirstMouse(for:)`, which
`NSTextInteractionView` doesn't override. That alone explains the result, so it says nothing
about the real app, whose window is key.

## Hypothesis

In the real app, drag events don't reach `NSTextInteractionView`, or they reach it with no
`dragStart`. A double-click still works, so the user can only ever get one word.

Possible causes:

- SwiftUI's hosting or gesture routing on macOS 26 (Darwin 25) delivering `leftMouseDragged`
  somewhere else.
- `mouseDown` with `clickCount == 1` not arriving, or arriving late, the same way it failed in
  the probe. Without it, `dragStart` is `nil` and `mouseDragged` returns early.
- `closestPosition(to:)` returning `nil` at mouse-down in the live app because the layout
  collection is empty or stale (compare upstream #71, #87 and #89). In the probe it didn't.

The answers to the four questions above will tell these apart. For example, if drag fails but
Shift+→ extends a double-clicked word, the model is fine and the problem is event delivery.

## Next steps

- Reproduce in `Examples/TextualDemo` on macOS 26 by hand. If drag fails there too, it is
  purely Textual's or SwiftUI's problem.
- Temporarily log `clickCount`, `dragStart` and `closestPosition` in `NSTextInteractionView`'s
  `mouseDown`, `mouseDragged` and `mouseUp`, then drag in a real app.
- Consider overriding `acceptsFirstMouse(for:)` to return `true`, so a click into an inactive
  window starts a selection the way it does in `NSTextView`. That fixes a related inactive-window
  case but may not be this bug.

## Findings (2026-11-06)

A copy of Twain was built against the local Textual checkout, with an in-process probe in its
`AppDelegate`. The probe opened `test.md` through `NSDocumentController`, so the real
`DocumentGroup` window was used. Launched with `open`, the app is active and its window is key.
The probe sent mouse events through `NSApp.sendEvent`, the same dispatch path as hardware
events, and read the selection back with `copy:`.

| Drag that starts with | Before the fix | After the fix |
|---|---|---|
| single click (`clickCount == 1`) | whole span ✓ (also slow 80-step drags, debug and release) | whole span ✓ |
| double click (`clickCount == 2`) | **one word (`"tis"`)** | word by word across blocks ✓ |
| triple click (`clickCount == 3`) | one block | block by block ✓ |

- Event delivery is fine. The `NSPanGestureRecognizer`s that SwiftUI puts on each
  `HostingScrollView` have `buttonMask = 0`, so they never take mouse drags. Hit testing and
  exclusion rects are correct, and the highlight draws across the dragged span.
- Cause: `mouseDown` with `clickCount == 2` or `3` selected the word or block and set
  `dragStart = nil`, so `mouseDragged` returned early. A double-click-and-drag, or a trackpad
  double-tap drag with tap to click, therefore never got past one word. `NSTextView` extends
  such a drag by words or paragraphs.
- Fix: `NSTextInteractionView` keeps the range the mouse-down selected as `dragAnchor`, with a
  granularity (character, word, block). A drag grows the selection from that anchor towards the
  word or block under the pointer. It also sets `selectionAnchor`, so after a backwards drag
  Shift-arrow keys move the start. Covered by `NSTextInteractionViewTests`.
- Not verified: whether the reporter's gesture really was a double-click or double-tap drag. A
  plain single-click drag worked even before the fix. If the bug still shows with a physical
  single click and drag, log `clickCount` in `mouseDown` in the live app.

## Related upstream issues (gonzalezreal/textual)

No existing issue matches this. The closest ones are:

- #99: Mac Catalyst double-click no longer selects a word since 0.4.0, with fix PR #100.
- #93: `NSTextInteractionView` traps keyboard focus.
- #71: selection fails for short, single-frame layouts. The fork has this fix as `32435f6`.
- #87 and #89: stale selection range after a content update or reflow.
