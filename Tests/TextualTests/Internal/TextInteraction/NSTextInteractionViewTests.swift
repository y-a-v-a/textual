#if TEXTUAL_ENABLE_TEXT_SELECTION && os(macOS)
  import SwiftUI
  import Testing

  @testable import Textual

  /// Drives `NSTextInteractionView` with mouse events over rendered text, so click counts, drags
  /// and the hit testing behind them are checked against real text layouts.
  @MainActor
  struct NSTextInteractionViewTests {
    private static let markdown = """
      Alpha beta gamma.

      Delta epsilon zeta.
      """

    @Test func dragExtendsTheSelectionByCharacters() throws {
      // given
      let fixture = try Fixture(rendering: Self.markdown)

      // when
      try fixture.drag(clickCount: 1, from: 8, to: 26)

      // then
      #expect(fixture.selectedText == "ta gamma.Delta eps")
    }

    @Test func doubleClickDragExtendsTheSelectionByWords() throws {
      // given
      let fixture = try Fixture(rendering: Self.markdown)

      // when: from inside "beta" to inside "epsilon"
      try fixture.drag(clickCount: 2, from: 8, to: 26)

      // then
      #expect(fixture.selectedText == "beta gamma.Delta epsilon")
    }

    @Test func doubleClickDragBackwardsKeepsTheClickedWord() throws {
      // given
      let fixture = try Fixture(rendering: Self.markdown)

      // when: from inside "epsilon" back to inside "beta"
      try fixture.drag(clickCount: 2, from: 26, to: 8)

      // then
      #expect(fixture.selectedText == "beta gamma.Delta epsilon")
    }

    @Test func tripleClickDragExtendsTheSelectionByBlocks() throws {
      // given
      let fixture = try Fixture(rendering: Self.markdown)

      // when
      try fixture.drag(clickCount: 3, from: 8, to: 26)

      // then
      #expect(fixture.selectedText == "Alpha beta gamma.Delta epsilon zeta.")
    }

    @Test func shiftArrowMovesTheEndABackwardsDragMoved() throws {
      // given: a drag from inside "epsilon" back to inside "beta"
      let fixture = try Fixture(rendering: Self.markdown)
      try fixture.drag(clickCount: 2, from: 26, to: 8)

      // when
      fixture.view.moveLeftAndModifySelection(nil)

      // then: the start moves, taking in the space before "beta"
      #expect(fixture.selectedText == " beta gamma.Delta epsilon")
    }

    @MainActor
    private struct Fixture {
      let window: NSWindow
      let view: NSTextInteractionView

      var model: TextSelectionModel {
        view.model
      }

      var selectedText: String? {
        model.selectedRange.map(model.text(in:))
      }

      init(rendering markdown: String) throws {
        let hostingView = NSHostingView(
          rootView: StructuredText(markdown: markdown)
            .textual.textSelection(.enabled)
            .frame(width: 300)
        )
        window = NSWindow(
          contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
          styleMask: .borderless,
          backing: .buffered,
          defer: false
        )
        window.contentView = hostingView

        // Text layouts reach the selection model through preferences, a few updates later
        let deadline = Date(timeIntervalSinceNow: 0.25)
        while Date() < deadline {
          hostingView.layoutSubtreeIfNeeded()
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        view = try #require(Self.interactionView(in: hostingView))
      }

      /// Presses at the character at `startOffset`, drags to the one at `endOffset` and releases.
      func drag(clickCount: Int, from startOffset: Int, to endOffset: Int) throws {
        let start = try location(ofCharacterAt: startOffset)
        let end = try location(ofCharacterAt: endOffset)

        for count in 1..<clickCount {
          view.mouseDown(with: event(.leftMouseDown, at: start, clickCount: count))
          view.mouseUp(with: event(.leftMouseUp, at: start, clickCount: count))
        }
        view.mouseDown(with: event(.leftMouseDown, at: start, clickCount: clickCount))
        for step in 1...4 {
          let fraction = CGFloat(step) / 4
          let point = CGPoint(
            x: start.x + (end.x - start.x) * fraction,
            y: start.y + (end.y - start.y) * fraction
          )
          view.mouseDragged(with: event(.leftMouseDragged, at: point, clickCount: clickCount))
        }
        view.mouseUp(with: event(.leftMouseUp, at: end, clickCount: clickCount))
      }

      /// The middle of the character at `offset`, in the interaction view's coordinates.
      private func location(ofCharacterAt offset: Int) throws -> CGPoint {
        let start = try #require(model.position(from: model.startPosition, offset: offset))
        let end = try #require(model.position(from: start, offset: 1))
        let rect = model.firstRect(for: TextRange(from: start, to: end))
        return CGPoint(x: rect.midX, y: rect.midY)
      }

      private func event(
        _ type: NSEvent.EventType,
        at point: CGPoint,
        clickCount: Int
      ) -> NSEvent {
        NSEvent.mouseEvent(
          with: type,
          location: view.convert(point, to: nil),
          modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: window.windowNumber,
          context: nil,
          eventNumber: 0,
          clickCount: clickCount,
          pressure: 1
        )!
      }

      private static func interactionView(in view: NSView) -> NSTextInteractionView? {
        if let interactionView = view as? NSTextInteractionView {
          return interactionView
        }
        return view.subviews.lazy.compactMap(interactionView(in:)).first
      }
    }
  }
#endif
