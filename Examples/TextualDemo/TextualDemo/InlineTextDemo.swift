import SwiftUI
import Textual

struct InlineTextDemo: View {
  var body: some View {
    Form {
      Section("Images") {
        InlineText(
          markdown: """
            This is a *lighthearted* but **perfectly serious** paragraph where `inline code` lives \
            happily alongside ~~a terrible idea~~ a better one, a [useful link](https://example.com), \
            and a bit of _extra emphasis_ just for style. To keep things interesting without overdoing \
            it, here’s a completely random image that adapts to the container width:

            ![Random image](https://picsum.photos/seed/textual/400/250)
            """
        )
        .textual.textSelection(.enabled)
      }
      Section("Custom Emoji") {
        InlineText(
          markdown: """
            **Working late on the new feature** has been surprisingly fun—_even when the build \
            fails_ :confused_dog:, a quick refactor usually gets things back on track :doge:, \
            and when it doesn’t, I just roll with it :dogroll: until the solution finally \
            clicks (though sometimes I still end up a bit **:confused_dog:** or _small \
            :confused_dog:_... plus another :confused_dog: for good measure).
            """,
          syntaxExtensions: [.emoji(.mastoEmoji)]
        )
        .textual.inlineStyle(
          InlineStyle()
            .strong(.bold, .fontScale(1.3))
            .emphasis(.italic, .fontScale(0.85))
        )
      }
      Section("Custom Inline Style") {
        InlineText(
          markdown: """
            This is a *lighthearted* but **perfectly serious** paragraph where `inline code` lives \
            happily alongside ~~a terrible idea~~ a better one, a [useful link](https://example.com), \
            and a bit of _extra emphasis_ just for style.
            """
        )
        .textual.inlineStyle(.custom)
      }
      Section("Text Run Effects") {
        InlineText(
          markdown: """
            A **highlighter pen** draws behind the text, while a ~~cross-out~~ draws over it.
            Both are plain `GraphicsContext` drawing, so an effect can be anything you can paint.
            """
        )
        .textual.inlineStyle(
          InlineStyle()
            .strong(.bold, .textRunEffect(HighlightEffect(color: .yellow)))
            .strikethrough(.textRunEffect(CrossOutEffect(color: .red), placement: .inFront))
        )
      }
    }
    .formStyle(.grouped)
  }
}

/// A highlighter-pen wash behind the text.
struct HighlightEffect: TextRunEffect {
  var color: Color

  func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
    let bounds = run.typographicBounds.rect.insetBy(dx: -2, dy: -1)
    context.fill(Path(roundedRect: bounds, cornerRadius: 3), with: .color(color.opacity(0.5)))
  }
}

/// A cross-out drawn over the text.
struct CrossOutEffect: TextRunEffect {
  var color: Color

  func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
    let bounds = run.typographicBounds.rect
    var path = Path()
    path.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
    path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))

    context.stroke(path, with: .color(color), lineWidth: 2)
  }
}

extension InlineStyle {
  fileprivate static var custom: InlineStyle {
    InlineStyle()
      .code(
        .monospaced,
        .fontScale(0.85),
        .backgroundColor(.purple),
        .foregroundColor(.white)
      )
      .emphasis(.italic, .underlineStyle(.single))
      .strikethrough(.foregroundColor(.secondary))
      .link(.foregroundColor(.purple), .underlineStyle(.init(pattern: .dot)))
  }
}

#Preview {
  InlineTextDemo()
}
