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
// - TextSelectionBackground renders selection highlights on macOS
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
// TextFragment is used by InlineText and StructuredText (via BlockContent) to render
// attributed content with inline attachments, links, and selection.

struct TextFragment<Content: AttributedStringProtocol>: View {
  @Environment(\.textEnvironment) private var textEnvironment
  @State private var textBuilder: TextBuilder?

  private let content: Content
  private let attachments: Set<AnyAttachment>
  private let hasLinks: Bool

  init(_ content: Content) {
    self.content = content
    // Both are needed on every body pass to decide which fragment-level overlays to install.
    // Resolve them in a single scan over the runs instead of one scan per lookup.
    (self.attachments, self.hasLinks) = content.attachmentsAndLinks()
  }

  var body: some View {
    Group {
      // Observing the container size only matters for attachments, whose placeholder sizes are
      // recomputed as the container resizes. Installing the observer on every fragment adds a
      // geometry node per block, which is the dominant cost in a large document.
      if attachments.isEmpty {
        text
      } else {
        text
          .onGeometryChange(for: CGSize?.self, of: \.textContainerSize) { size in
            guard let size, let textBuilder else { return }
            textBuilder.sizeChanged(size, environment: textEnvironment)
          }
      }
    }
    .onChange(of: content, initial: true) { _, newValue in
      self.textBuilder = TextBuilder(newValue, environment: textEnvironment)
    }
    .modifier(TextSelectionBackground())
    .modifier(AttachmentOverlay(attachments: attachments))
    .modifier(TextLinkInteraction(hasLinks: hasLinks))
  }

  private var text: Text {
    // The marker identifies this fragment to any `Text.Layout` consumer, so it is always applied.
    (textBuilder?.text ?? Text(verbatim: "")).customAttribute(TextFragmentAttribute())
  }
}

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
