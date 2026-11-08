import SwiftUI

// MARK: - Overview
//
// TextFragment renders attributed content as SwiftUI.Text with support for inline
// attachments, links, and selection. It uses a TextBuilder to construct and cache
// Text values, minimizing rebuilds during resize by keying on attachment sizes.
//
// Attachments are represented as placeholder images tagged with AttachmentAttribute. The
// actual attachment views are rendered in an overlay using the resolved Text.Layout
// geometry. Three modifiers are applied at the fragment level:
//
// - TextSelectionBackground renders selection highlights on macOS, above any run background
//   colors it takes over from the text (see TextBackground)
// - AttachmentOverlay draws attachments at their run locations with selection-aware dimming
// - TextLinkInteraction handles tap gestures on links
//
// These overlays use backgroundPreferenceValue and overlayPreferenceValue to access
// Text.Layout and render in fragment-local coordinates. Fragment-level overlays enable
// coordinate space isolation and keep scrollable regions interactive.
//
// An ancestor view must define a named coordinate space (.textContainer) for the text
// container. TextFragment uses onGeometryChange to observe the container size and rebuild
// Text when attachment sizes need to change.
//
// The TextBuilder is derived in body rather than seeded from onChange(initial:), so the text is
// there on the fragment's first layout pass. Seeded from that event, the fragment first lays out
// empty, which a List measures as the row's height, and a fragment that a lazy container
// materializes can miss the event altogether.
//
// TextFragment is used by InlineText and StructuredText (via BlockContent) to render
// attributed content with inline attachments, links, and selection.

struct TextFragment<Content: AttributedStringProtocol>: View {
  @Environment(\.textEnvironment) private var textEnvironment

  #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Environment(\.textSelection) private var textSelection
  #endif

  // Rebuilt when the content, the text environment (fonts, dynamic type, color scheme), or
  // whether run backgrounds are lifted out of the text changes
  @State private var textBuilder = Memo<Tuple<Content, TextEnvironmentValues, Bool>, TextBuilder>()

  // The container size last reported to a builder. A new builder starts from it, because the
  // container may not change size again to report it, such as when only the color scheme changes.
  @State private var containerSize = Box<CGSize?>(nil)

  // All three features are needed on every body pass to decide which fragment-level overlays
  // and renderers to install. They are resolved in a single scan over the runs, memoized so
  // the scan happens per content change rather than per body evaluation.
  @State private var inlineFeatures = Memo<Content, InlineFeatures>()

  private let content: Content

  init(_ content: Content) {
    self.content = content
  }

  var body: some View {
    let (attachments, hasLinks, hasTextRunEffects, hasBackgroundColors) = inlineFeatures(
      content
    ) {
      content.inlineFeatures()
    }
    let liftsBackgroundColors = hasBackgroundColors && paintsSelectionBehindText
    let builder = textBuilder(Tuple(content, textEnvironment, liftsBackgroundColors)) {
      TextBuilder(
        content,
        containerSize: containerSize.wrappedValue,
        liftsBackgroundColors: liftsBackgroundColors,
        environment: textEnvironment
      )
    }

    Group {
      // Observing the container size only matters for attachments, whose placeholder sizes are
      // recomputed as the container resizes. Installing the observer on every fragment adds a
      // geometry node per block, which is the dominant cost in a large document.
      if attachments.isEmpty {
        textView(builder, hasTextRunEffects: hasTextRunEffects)
      } else {
        textView(builder, hasTextRunEffects: hasTextRunEffects)
          .onGeometryChange(for: CGSize?.self, of: \.textContainerSize) { size in
            guard let size else { return }
            containerSize.wrappedValue = size
            builder.sizeChanged(size, environment: textEnvironment)
          }
      }
    }
    .modifier(TextSelectionBackground(drawsTextBackgrounds: liftsBackgroundColors))
    .modifier(AttachmentOverlay(attachments: attachments))
    .modifier(TextLinkInteraction(hasLinks: hasLinks))
  }

  // On macOS the selection highlight is painted behind the text, where a background color drawn
  // by the `Text` itself would cover it. Those backgrounds are then painted by
  // TextSelectionBackground instead, below the highlight.
  private var paintsSelectionBehindText: Bool {
    #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit) && !targetEnvironment(macCatalyst)
      textSelection.allowsSelection
    #else
      false
    #endif
  }

  // The custom renderer is installed only where it earns its place. Fragments without effects
  // keep SwiftUI's own text rendering path, so nothing about how the rest of a document draws
  // depends on a feature it does not use.
  @ViewBuilder private func textView(
    _ builder: TextBuilder, hasTextRunEffects: Bool
  ) -> some View {
    if hasTextRunEffects {
      text(builder).textRenderer(TextRunEffectRenderer())
    } else {
      text(builder)
    }
  }

  private func text(_ builder: TextBuilder) -> Text {
    var text = builder.text

    if let accessibilityLabel = builder.accessibilityLabel {
      text = text.accessibilityLabel(Text(verbatim: accessibilityLabel))
    }

    // The marker identifies this fragment to any `Text.Layout` consumer, so it is always applied.
    return text.customAttribute(TextFragmentAttribute())
  }
}

private typealias InlineFeatures = (
  attachments: Set<AnyAttachment>, hasLinks: Bool, hasTextRunEffects: Bool,
  hasBackgroundColors: Bool
)

struct TextFragmentAttribute: TextAttribute {
}

extension Text.Layout {
  var isTextFragment: Bool {
    first?.first?[TextFragmentAttribute.self] != nil
  }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  static var textContainer: NamedCoordinateSpace {
    .named("textContainer")
  }
}

extension GeometryProxy {
  fileprivate var textContainerSize: CGSize? {
    bounds(of: .textContainer)?.size
  }
}
