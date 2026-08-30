import Foundation

/// A ``MarkupParser`` implementation backed by Foundation’s Markdown support.
///
/// This parser leverages Foundation’s Markdown support and preserves structure via
/// presentation intents.
///
/// This parser can process its output to expand custom emoji and math expressions into
/// inline attachments.
public struct AttributedStringMarkdownParser: MarkupParser {
  private let baseURL: URL?
  private let options: AttributedString.MarkdownParsingOptions
  private let processor: PatternProcessor

  public init(
    baseURL: URL?,
    options: AttributedString.MarkdownParsingOptions = .init(),
    syntaxExtensions: [SyntaxExtension] = []
  ) {
    self.baseURL = baseURL
    self.options = options
    self.processor = PatternProcessor(syntaxExtensions: syntaxExtensions)
  }

  public func attributedString(for input: String) throws -> AttributedString {
    // Escaped task list markers (`\[ ]`) parse to the same text as real ones, so they can
    // only be told apart through source positions while the source is still at hand
    var options = self.options
    let detectsEscapedMarkers = EscapedTaskListMarkers.mayContain(input)

    if detectsEscapedMarkers {
      options.appliesSourcePositionAttributes = true
    }

    var output = try AttributedString(
      markdown: input,
      including: \.textual,
      options: options,
      baseURL: baseURL
    )

    if detectsEscapedMarkers {
      EscapedTaskListMarkers.mark(in: &output, source: input)

      if !self.options.appliesSourcePositionAttributes {
        output.markdownSourcePosition = nil
      }
    }

    return try processor.expand(output)
  }
}

extension MarkupParser where Self == AttributedStringMarkdownParser {
  /// Creates a Markdown parser configured for inline-only syntax.
  public static func inlineMarkdown(
    baseURL: URL? = nil,
    syntaxExtensions: [AttributedStringMarkdownParser.SyntaxExtension] = []
  ) -> Self {
    .init(
      baseURL: baseURL,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace),
      syntaxExtensions: syntaxExtensions
    )
  }

  /// Creates a Markdown parser configured for full-document syntax.
  public static func markdown(
    baseURL: URL? = nil,
    syntaxExtensions: [AttributedStringMarkdownParser.SyntaxExtension] = []
  ) -> Self {
    .init(
      baseURL: baseURL,
      syntaxExtensions: syntaxExtensions
    )
  }
}
