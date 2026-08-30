import SwiftUI

/// Controls when ``StructuredText`` syntax-highlights fenced code blocks.
///
/// You can set the mode using the ``TextualNamespace/syntaxHighlightingMode(_:)`` modifier. The
/// default is ``SyntaxHighlightingMode/asynchronous``.
public enum SyntaxHighlightingMode: Hashable, Sendable {
  /// Highlights code blocks asynchronously, off the main actor.
  ///
  /// Code appears unhighlighted for a frame or two and gains color once tokenization
  /// finishes. This keeps scrolling smooth and is the right choice for anything on screen.
  case asynchronous

  /// Highlights code blocks synchronously, while the view body is evaluated.
  ///
  /// Use this mode for offscreen rendering — `ImageRenderer`, PDF export, printing — where
  /// asynchronous tokenization never gets a chance to reach the drawing pass, so code prints
  /// uncolored no matter how long you wait:
  ///
  /// ```swift
  /// let renderer = ImageRenderer(
  ///   content: StructuredText(markdown: markdown)
  ///     .textual.syntaxHighlightingMode(.synchronous)
  /// )
  /// let image = renderer.cgImage
  /// ```
  ///
  /// - Important: Tokenization runs on the main actor and blocks it. Prefer
  ///   ``SyntaxHighlightingMode/asynchronous`` for content that is on screen.
  case synchronous
}

extension EnvironmentValues {
  @usableFromInline
  @Entry var syntaxHighlightingMode = SyntaxHighlightingMode.asynchronous
}
