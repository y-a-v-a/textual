#if os(iOS) && !targetEnvironment(macCatalyst)
  import SnapshotTesting
  import SwiftUI
  import Testing

  import Textual

  @MainActor
  struct TextRunEffectSnapshotTests {
    private let layout = SwiftUISnapshotLayout.device(config: .iPhone8)

    /// A highlighter-pen wash behind the text.
    private struct HighlightEffect: TextRunEffect {
      var color: Color

      func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
        let bounds = run.typographicBounds.rect.insetBy(dx: -2, dy: -1)
        context.fill(Path(roundedRect: bounds, cornerRadius: 3), with: .color(color))
      }
    }

    /// A cross-out drawn over the text.
    private struct CrossOutEffect: TextRunEffect {
      var color: Color

      func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
        let bounds = run.typographicBounds.rect
        var path = Path()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))

        context.stroke(path, with: .color(color), lineWidth: 2)
      }
    }

    @Test func highlightBehindText() {
      let view = StructuredText(
        markdown: """
          The sky above the port was the color of **television**, tuned to a dead channel.
          """
      )
      .padding(.horizontal)
      .textual.inlineStyle(
        InlineStyle().strong(.bold, .textRunEffect(HighlightEffect(color: .yellow)))
      )

      assertSnapshot(of: view, as: .textualImage(layout: layout))
    }

    @Test func crossOutInFrontOfText() {
      let view = StructuredText(
        markdown: """
          It was a bright cold day in April, and the clocks were **striking thirteen**.
          """
      )
      .padding(.horizontal)
      .textual.inlineStyle(
        InlineStyle().strong(
          .bold,
          .textRunEffect(CrossOutEffect(color: .red), placement: .inFront)
        )
      )

      assertSnapshot(of: view, as: .textualImage(layout: layout))
    }

    @Test func effectsCoexistWithLinksAndAttachments() {
      let view = StructuredText(
        markdown: """
          A **highlighted** span, a [link](https://example.com), and a math expression
          $A = \\pi r^2$ share one fragment.
          """,
        syntaxExtensions: [.math]
      )
      .padding(.horizontal)
      .textual.inlineStyle(
        InlineStyle().strong(.bold, .textRunEffect(HighlightEffect(color: .yellow)))
      )

      assertSnapshot(of: view, as: .textualImage(layout: layout))
    }
  }
#endif
