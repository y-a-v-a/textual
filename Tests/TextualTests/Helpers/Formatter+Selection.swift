import Foundation
import Testing

@testable import Textual

extension Textual.Formatter {
  /// Creates a formatter for the first occurrence of `text` in the parsed `markdown`, the way
  /// text selection hands a selected range of a document to the formatter.
  convenience init(
    selecting text: String,
    in markdown: String,
    startsInsideBlock: Bool = false
  ) throws {
    let document = try AttributedString(
      NSAttributedString(markdown: markdown),
      including: \.textual
    )
    let range = try #require(document.range(of: text))

    self.init(AttributedString(document[range]), startsInsideBlock: startsInsideBlock)
  }
}
