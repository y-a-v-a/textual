// Mac Catalyst is excluded because `UIWindow` cannot be created in the test host.
#if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
  import SwiftUI
  import Testing

  import Textual

  // A container that sizes its rows on their own, such as a `List`, measures a view once before
  // any of its state settles. A view whose content only arrives through an appearance callback
  // measures empty on that pass, and the row then changes height under the list.
  @MainActor
  struct FirstLayoutPassTests {
    private static let width: CGFloat = 320

    @Test func structuredTextMeasuresItsContentOnTheFirstPass() async throws {
      let heights = try await Self.heights(
        of: StructuredText(
          markdown: """
            ## A heading

            A paragraph with `code`, **strong** text, and enough words to wrap onto a second \
            line at this width.

            - An item
            - Another item
            """
        )
      )

      #expect(heights.first > 0)
      #expect(heights.first == heights.settled)
    }

    @Test func inlineTextMeasuresItsContentOnTheFirstPass() async throws {
      let heights = try await Self.heights(
        of: InlineText(
          markdown: """
            Read the [contributing guide](https://example.com) first, then open a pull request \
            that explains what changed and why, so reviewers know where to look.
            """
        )
      )

      #expect(heights.first > 0)
      #expect(heights.first == heights.settled)
    }

    // An offscreen renderer, such as an export, draws a single pass and never delivers the
    // appearance callbacks, so content that only arrives through one never gets drawn
    @Test func imageRendererDrawsStructuredText() throws {
      let image = try #require(
        ImageRenderer(
          content: StructuredText(markdown: "A paragraph with **strong** text.")
            .frame(width: Self.width)
        ).cgImage
      )

      #expect(image.countPixels { _ in true } > 0)
    }

    @Test func imageRendererDrawsInlineText() throws {
      let image = try #require(
        ImageRenderer(
          content: InlineText(markdown: "Inline text with `code`.")
            .frame(width: Self.width)
        ).cgImage
      )

      #expect(image.countPixels { _ in true } > 0)
    }

    /// The height of `view` on the first sizing pass, and once its state has settled.
    private static func heights(
      of view: some View
    ) async throws -> (first: CGFloat, settled: CGFloat) {
      let proposal = CGSize(width: width, height: .greatestFiniteMagnitude)

      #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
      #else
        let controller = NSHostingController(rootView: view)
      #endif

      let first = controller.sizeThatFits(in: proposal).height

      // Suspending, rather than running the run loop from here, lets main actor work such as
      // tasks and throttled updates run as well
      for _ in 0..<4 {
        try await Task.sleep(for: .milliseconds(50))
        _ = controller.sizeThatFits(in: proposal)
      }

      return (first, controller.sizeThatFits(in: proposal).height)
    }
  }
#endif
