#if TEXTUAL_ENABLE_TEXT_SELECTION && os(macOS)
  import SwiftUI
  import Testing

  @testable import Textual

  /// Copies selections from rendered lists, so the selection layer and the formatter are checked
  /// together against real text layouts.
  @MainActor
  struct TextSelectionCopyTests {
    private static let list = """
      1. First item
      2. Second item
      3. Third item
      """

    @Test func copyingPartOfAListItemLeavesOutTheMarker() throws {
      // given
      let model = try Self.selectionModel(rendering: Self.list)
      // "First item" is 10 characters long, so offset 12 is the "c" in "Second"
      let start = try #require(model.position(from: model.startPosition, offset: 12))
      let end = try #require(model.position(from: start, offset: 7))
      let range = TextRange(from: start, to: end)

      // when
      let copied = Self.copiedText(in: range, of: model)

      // then
      #expect(copied == "cond it")
    }

    @Test func copyingFromInsideAListItemLeavesOutItsMarker() throws {
      // given
      let model = try Self.selectionModel(rendering: Self.list)
      let start = try #require(model.position(from: model.startPosition, offset: 12))
      let range = TextRange(from: start, to: model.endPosition)

      // when
      let copied = Self.copiedText(in: range, of: model)

      // then
      #expect(copied == "cond item\n  3. Third item")
    }

    @Test func copyingWholeListItemsKeepsTheirMarkers() throws {
      // given
      let model = try Self.selectionModel(rendering: Self.list)
      let start = try #require(model.position(from: model.startPosition, offset: 10))
      let range = TextRange(from: start, to: model.endPosition)

      // when
      let copied = Self.copiedText(in: range, of: model)

      // then
      #expect(copied == "  2. Second item\n  3. Third item")
    }

    /// Formats the text in `range` the way the copy command does.
    private static func copiedText(in range: Textual.TextRange, of model: TextSelectionModel)
      -> String
    {
      Formatter(
        model.attributedText(in: range),
        startsInsideBlock: model.startsInsideBlock(range)
      ).plainText()
    }

    private static func selectionModel(rendering markdown: String) throws -> TextSelectionModel {
      let hostingView = NSHostingView(
        rootView: StructuredText(markdown: markdown)
          .textual.textSelection(.enabled)
          .frame(width: 300)
      )
      let window = NSWindow(
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

      let interactionView = try #require(Self.interactionView(in: hostingView))
      return interactionView.model
    }

    private static func interactionView(in view: NSView) -> NSTextInteractionView? {
      if let interactionView = view as? NSTextInteractionView {
        return interactionView
      }
      return view.subviews.lazy.compactMap(interactionView(in:)).first
    }
  }
#endif
