#if TEXTUAL_ENABLE_TEXT_SELECTION && os(macOS)
  import AppKit
  import SwiftUI
  import Testing

  @testable import Textual

  @MainActor
  struct TextBackgroundTests {
    // With selection enabled, run backgrounds are painted by TextBackgroundView instead of by the
    // `Text` itself. The result should look the same as SwiftUI's own drawing.
    @Test(arguments: [1.0, 2.0, 3.0])
    func liftedBackgroundsMatchSwiftUIBackgrounds(scale: CGFloat) throws {
      let drawnByText = try Self.bitmap(selectable: false, scale: scale)
      let drawnBehind = try Self.bitmap(selectable: true, scale: scale)

      try #require(drawnByText.pixelsWide == drawnBehind.pixelsWide)
      try #require(drawnByText.pixelsHigh == drawnBehind.pixelsHigh)

      var differing = 0
      for y in 0..<drawnByText.pixelsHigh {
        for x in 0..<drawnByText.pixelsWide {
          let a = drawnByText.colorAt(x: x, y: y)!
          let b = drawnBehind.colorAt(x: x, y: y)!
          if abs(a.redComponent - b.redComponent) > 0.02
            || abs(a.greenComponent - b.greenComponent) > 0.02
            || abs(a.blueComponent - b.blueComponent) > 0.02
          {
            differing += 1
          }
        }
      }
      #expect(differing == 0)
    }

    // The selection highlight is painted behind the text on macOS. A selection across inline code
    // must cover the code's background rather than be covered by it.
    @Test func selectionHighlightCoversInlineCodeBackground() throws {
      let hostingView = NSHostingView(
        rootView: InlineText(markdown: "Run `swift build` then `swift test --parallel` now.")
          .textual.inlineStyle(
            InlineStyle().code(.monospaced, .fontScale(0.85), .backgroundColor(Color(red: 1, green: 0, blue: 0)))
          )
          .textual.textSelection(.enabled)
          .frame(width: 240)
          .background(Color.white)
          .environment(\.colorScheme, .light)
      )
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )
      window.appearance = NSAppearance(named: .aqua)
      window.contentView = hostingView
      Self.settle(hostingView)

      #expect(Self.countRedPixels(in: hostingView) > 0)

      let interactionView = try #require(Self.interactionView(in: hostingView))
      interactionView.selectAll(nil)
      Self.settle(hostingView)

      #expect(Self.countRedPixels(in: hostingView) == 0)
    }

    private static func settle(_ view: NSView) {
      // Text layouts and the selection reach their views through preferences, a few updates later
      let deadline = Date(timeIntervalSinceNow: 0.25)
      while Date() < deadline {
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      }
    }

    /// The pixels showing the pure red the code background is painted with.
    private static func countRedPixels(in view: NSView) -> Int {
      guard let rep = snapshot(view) else { return 0 }

      var count = 0
      for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
          // The components are the bitmap's own sRGB values
          guard let pixel = rep.colorAt(x: x, y: y) else { continue }
          if pixel.redComponent > 0.9 && pixel.greenComponent < 0.1 && pixel.blueComponent < 0.1 {
            count += 1
          }
        }
      }
      return count
    }

    /// Renders the view's layer tree, which includes the `Canvas` content that
    /// `cacheDisplay(in:to:)` leaves out.
    private static func snapshot(_ view: NSView) -> NSBitmapImageRep? {
      guard let layer = view.layer else { return nil }
      let scale = 2
      guard
        let context = CGContext(
          data: nil,
          width: Int(view.bounds.width) * scale,
          height: Int(view.bounds.height) * scale,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      else { return nil }
      context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
      layer.render(in: context)
      return context.makeImage().map(NSBitmapImageRep.init(cgImage:))
    }

    private static func interactionView(in view: NSView) -> NSTextInteractionView? {
      if let interactionView = view as? NSTextInteractionView {
        return interactionView
      }
      return view.subviews.lazy.compactMap(interactionView(in:)).first
    }

    private static var content: AttributedString {
      func code(_ string: String) -> AttributedString {
        var code = AttributedString(string)
        code.font = .system(size: 11, design: .monospaced)
        code.backgroundColor = Color(red: 0.85, green: 0.9, blue: 0.95)
        return code
      }
      return AttributedString("Run ") + code("swift build") + AttributedString(" then ")
        + code("swift test --parallel") + AttributedString(" before you push a change.")
    }

    // `TextFragment` on its own, so the selection interaction's AppKit view (which
    // `ImageRenderer` cannot draw) is not installed, while the fragment still sees selection
    // as enabled.
    private static func bitmap(selectable: Bool, scale: CGFloat) throws -> NSBitmapImageRep {
      let content = TextFragment(Self.content)
      .environment(
        \.textSelection,
        selectable ? EnabledTextSelectability.self : DisabledTextSelectability.self
      )
      .frame(width: 240, alignment: .leading)
      .coordinateSpace(.textContainer)
      .fixedSize(horizontal: false, vertical: true)
      .background(Color.white)
      .environment(\.colorScheme, .light)
      .environment(\.displayScale, scale)

      let renderer = ImageRenderer(content: content)
      renderer.scale = scale
      let image = try #require(renderer.cgImage)
      return NSBitmapImageRep(cgImage: image)
    }
  }
#endif
