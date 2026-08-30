// JavaScriptCore, and therefore syntax highlighting, is unavailable on watchOS.
// Mac Catalyst is excluded because `UIWindow` cannot be created in the test host.
#if canImport(JavaScriptCore) && (os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst)))
  import CoreGraphics
  import SwiftUI
  import Testing

  @testable import Textual

  @MainActor
  struct SyntaxHighlightingModeTests {
    private static let markdown = """
      ```swift
      let greeting = "Hello, world!"
      func greet() -> String { greeting }
      ```
      """

    @Test func synchronousHighlightingIsVisibleOnTheFirstDrawnFrame() throws {
      let image = try #require(
        OffscreenHost.firstFrame(
          of: StructuredText(markdown: Self.markdown)
            .textual.syntaxHighlightingMode(.synchronous)
        )
      )

      // Keywords, strings, and function names each contribute a hue
      #expect(image.distinctHueCount() > 1)
    }

    @Test func asynchronousHighlightingIsMissingFromTheFirstDrawnFrame() throws {
      // This is the limitation `.synchronous` exists to solve: an offscreen renderer draws
      // before asynchronous tokenization can deliver its tokens, so code prints uncolored.
      let image = try #require(
        OffscreenHost.firstFrame(of: StructuredText(markdown: Self.markdown))
      )

      #expect(image.distinctHueCount() == 0)
    }

    @Test func synchronousTokenizerHighlightsKnownLanguages() {
      let tokens = SynchronousCodeTokenizer.tokenize(
        code: "let greeting = \"Hello, world!\"",
        language: "swift"
      )

      #expect(
        tokens == [
          .init(content: "let", type: .keyword),
          .init(content: " greeting ", type: .plain),
          .init(content: "=", type: .operator),
          .init(content: " ", type: .plain),
          .init(content: "\"Hello, world!\"", type: .string),
        ]
      )
    }

    @Test func synchronousTokenizerFallsBackToPlainTextWithoutLanguage() {
      let tokens = SynchronousCodeTokenizer.tokenize(
        code: "let greeting = \"Hello, world!\"",
        language: nil
      )

      #expect(tokens == [.init(content: "let greeting = \"Hello, world!\"", type: .plain)])
    }

    @Test func synchronousTokenizerReusesResults() {
      let code = "let cached = true"

      let first = SynchronousCodeTokenizer.tokenize(code: code, language: "swift")
      let second = SynchronousCodeTokenizer.tokenize(code: code, language: "swift")

      #expect(first == second)
      #expect(first.count > 1)
    }
  }
#endif
