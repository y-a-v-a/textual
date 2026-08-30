import Foundation

// MARK: - Overview
//
// GitHub-flavored Markdown does not treat an escaped marker (`- \[ ] text`) as a task list
// item, but Foundation's Markdown parser consumes the escape, so the escaped and unescaped
// forms parse to identical text. The difference only exists in the Markdown source.
//
// When the source may contain an escaped marker, `AttributedStringMarkdownParser` parses with
// source positions enabled and calls `mark(in:source:)`, which reads each candidate marker
// back from the source. A leading `[` whose source spelling differs from its parsed text —
// because the bracket or a following character was escaped — is tagged with the
// `escapedTaskListMarker` attribute so task list detection leaves it literal.

enum EscapedTaskListMarkers {
  /// Whether the source can contain an escaped task list marker at all.
  ///
  /// This is the cheap pre-check that keeps escape handling out of the common parse path.
  static func mayContain(_ source: String) -> Bool {
    source.contains("\\[") || source.contains("\\]")
  }

  /// Tags parsed markers whose source spelling is escaped.
  ///
  /// Expects `output` to be parsed from `source` with source position attributes applied.
  static func mark(in output: inout AttributedString, source: String) {
    var escapedMarkerOffsets: [Int] = []

    for run in output.runs {
      // Mirror task list detection: the marker only counts when it is literal text
      guard run.inlinePresentationIntent?.isEmpty ?? true,
        !(run.presentationIntent?.isCodeBlock ?? false),
        let position = run.markdownSourcePosition
      else {
        continue
      }

      let text = output.characters[run.range]

      guard text.first == "[",
        let sourceStart = index(line: position.startLine, column: position.startColumn, in: source)
      else {
        continue
      }

      // A marker spans at most `[`, a state character, and `]`. A genuine one reads the same
      // in the source; an escape anywhere in it makes the source spelling differ.
      let parsedPrefix = text.prefix(3)
      let sourcePrefix = source[sourceStart...].prefix(parsedPrefix.count)

      if !parsedPrefix.elementsEqual(sourcePrefix) {
        escapedMarkerOffsets.append(
          output.characters.distance(from: output.startIndex, to: run.range.lowerBound)
        )
      }
    }

    for offset in escapedMarkerOffsets {
      let start = output.characters.index(output.startIndex, offsetBy: offset)
      let end = output.characters.index(after: start)
      output[start..<end].textual.escapedTaskListMarker = true
    }
  }

  /// Returns the index in `source` for a source position's 1-based line and UTF-8 byte column.
  private static func index(line: Int, column: Int, in source: String) -> String.Index? {
    let utf8 = source.utf8
    var lineStart = utf8.startIndex
    var currentLine = 1

    while currentLine < line {
      guard let newline = utf8[lineStart...].firstIndex(of: UInt8(ascii: "\n")) else {
        return nil
      }
      lineStart = utf8.index(after: newline)
      currentLine += 1
    }

    guard
      let position = utf8.index(lineStart, offsetBy: column - 1, limitedBy: utf8.endIndex),
      position < utf8.endIndex
    else {
      return nil
    }

    return String.Index(position, within: source)
  }
}

extension PresentationIntent {
  fileprivate var isCodeBlock: Bool {
    guard case .codeBlock = components.first?.kind else {
      return false
    }
    return true
  }
}
