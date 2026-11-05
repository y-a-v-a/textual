import Foundation

// MARK: - Overview
//
// Math expressions are replaced after Markdown parsing, but LaTeX and Markdown disagree about
// most punctuation: `\,` parses to `,`, `\{` to `{`, `a*b*c` gains an emphasis run, and the line
// breaks of a multi-line `$$` block split it across runs.
//
// `protect(in:options:)` rewrites the source so Markdown hands each expression back unchanged. It
// joins the lines of an expression and backslash-escapes its punctuation, which Markdown then
// removes again.
//
// Escaping is only safe where Markdown reads escapes, and code, HTML and URLs are not such
// places. Only Markdown itself can tell where those are, so a first parse with source positions
// classifies the source and the rewrite skips anything it does not recognize as plain text. An
// expression left alone that way is still replaced after parsing, as if it were never protected.
//
// Documents without a candidate expression never get that first parse. Source positions that a
// caller asks for describe the rewritten source.

enum MathSource {
  /// Whether the source can contain a math expression at all.
  static func mayContain(_ source: String) -> Bool {
    source.contains("$")
  }

  /// Returns `source` with its math expressions rewritten to survive Markdown parsing.
  static func protect(
    in source: String,
    options: AttributedString.MarkdownParsingOptions
  ) throws -> String {
    let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isLineBreak)
    let patterns: [PatternTokenizer.Pattern] = [.mathBlock, .mathInline]

    var classification: SourceClassification?
    var output = ""
    var copiedUpTo = source.startIndex

    for paragraph in paragraphs(in: lines, of: source) {
      var cursor = paragraph.startIndex

      while let dollar = paragraph[cursor...].firstIndex(of: "$") {
        let afterDollar = paragraph.index(after: dollar)

        guard !isEscaped(dollar, in: source),
          let match = try firstMatch(of: patterns, at: paragraph[dollar...])
        else {
          cursor = afterDollar
          continue
        }

        // Parsed only once something looks like math
        let parsed = try classification ?? SourceClassification(source, lines, options)
        classification = parsed

        guard parsed.isProtectable(match.range, in: source) else {
          cursor = afterDollar
          continue
        }

        output += source[copiedUpTo..<dollar]
        output += replacement(for: match, in: source)
        copiedUpTo = match.range.upperBound
        cursor = copiedUpTo
      }
    }

    guard copiedUpTo > source.startIndex else {
      return source
    }

    output += source[copiedUpTo...]
    return output
  }

  /// Splits the source on blank lines, which an expression never crosses.
  ///
  /// A line holding only block quote markers counts as blank.
  private static func paragraphs(
    in lines: [Substring],
    of source: String
  ) -> [Substring] {
    lines.split { line in
      line.allSatisfy { $0 == ">" || $0.isWhitespace }
    }
    .compactMap { lines in
      guard let first = lines.first, let last = lines.last else {
        return nil
      }
      return source[first.startIndex..<last.endIndex]
    }
  }

  /// Whether an odd number of backslashes precedes the index.
  private static func isEscaped(_ index: String.Index, in source: String) -> Bool {
    source[..<index].reversed().prefix { $0 == "\\" }.count % 2 == 1
  }

  private static func firstMatch(
    of patterns: [PatternTokenizer.Pattern],
    at text: Substring
  ) throws -> Regex<(Substring, Substring)>.Match? {
    for pattern in patterns {
      if let match = try pattern.regex.prefixMatch(in: text) {
        return match
      }
    }
    return nil
  }

  private static func replacement(
    for match: Regex<(Substring, Substring)>.Match,
    in source: String
  ) -> String {
    let content = match.output.1
    let delimiter = source[match.range.lowerBound..<content.startIndex]
    let joined = joiningLines(of: content, startingAt: match.range.lowerBound, in: source)

    var escaped = String(delimiter)
    for character in joined {
      if asciiPunctuation.contains(character) {
        escaped.append("\\")
      }
      escaped.append(character)
    }
    return escaped + delimiter
  }

  /// Joins the lines of an expression, without the block quote markers Markdown would have
  /// removed from them.
  ///
  /// Markers are only removed up to the depth of the line the expression starts on, since a `>`
  /// beyond that is part of the formula.
  private static func joiningLines(
    of content: Substring,
    startingAt start: String.Index,
    in source: String
  ) -> Substring {
    let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isLineBreak)

    guard lines.count > 1 else {
      return content
    }

    let lineStart = source[..<start].lastIndex(where: \.isLineBreak).map(source.index(after:))
    let quoteDepth = source[(lineStart ?? source.startIndex)..<start].count { $0 == ">" }

    let joined =
      lines
      .enumerated()
      .map { index, line in
        var line = line
        if index > 0 {
          for _ in 0..<quoteDepth {
            let trimmed = line.drop(while: \.isWhitespace)
            guard trimmed.first == ">" else {
              break
            }
            line = trimmed.dropFirst()
          }
        }
        return line.trimmingCharacters(in: .whitespaces)
      }
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    return joined[...]
  }

  /// The characters CommonMark allows a backslash to escape.
  private static let asciiPunctuation = Set(##"!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~"##)
}

/// What a first parse found at each place in the source.
private struct SourceClassification {
  private enum Kind {
    /// Text whose source is read as Markdown, so an escape in it is removed again.
    case plain
    /// Source that keeps backslashes, which an expression can't be escaped across.
    case code
    /// Source an expression can pass through but shouldn't start or end in.
    case other

    init(_ run: AttributedString.Runs.Run) {
      let inline = run.inlinePresentationIntent ?? []

      if inline.contains(.code) || inline.contains(.blockHTML)
        || run.presentationIntent?.isCodeBlock == true
      {
        self = .code
      } else if inline.contains(.inlineHTML) || run.link != nil {
        self = .other
      } else {
        self = .plain
      }
    }
  }

  private struct Entry {
    let range: Range<Int>
    let kind: Kind
    let line: Int
  }

  /// Sorted by location. Ranges are UTF-8 offsets, which is what source positions count.
  private let entries: [Entry]

  init(
    _ source: String,
    _ lines: [Substring],
    _ options: AttributedString.MarkdownParsingOptions
  ) throws {
    var options = options
    options.appliesSourcePositionAttributes = true

    let parsed = try AttributedString(markdown: source, options: options)
    let bytes = Array(source.utf8)
    let lineOffsets = lines.map { source.utf8.distance(from: source.startIndex, to: $0.startIndex) }

    var entries: [Entry] = []
    var misplacedLines = Set<Int>()

    for run in parsed.runs {
      guard let position = run.markdownSourcePosition,
        lineOffsets.indices.contains(position.startLine - 1),
        lineOffsets.indices.contains(position.endLine - 1)
      else {
        continue
      }

      let line = position.startLine - 1
      let lower = lineOffsets[line] + position.startColumn - 1
      let upper = lineOffsets[position.endLine - 1] + position.endColumn

      guard lower < upper else {
        continue
      }

      let kind = Kind(run)
      entries.append(Entry(range: lower..<upper, kind: kind, line: line))

      // The source of a code span is literal, so one that doesn't read back from its reported
      // position shows that the columns of its line are off (see `isProtectable`).
      if kind == .code, position.startLine == position.endLine,
        upper > bytes.count
          || !bytes[lower..<upper].elementsEqual(String(parsed[run.range].characters).utf8)
      {
        misplacedLines.insert(line)
      }
    }

    entries.removeAll { misplacedLines.contains($0.line) }

    for line in misplacedLines {
      let upper = lineOffsets.indices.contains(line + 1) ? lineOffsets[line + 1] : bytes.count
      entries.append(Entry(range: lineOffsets[line]..<upper, kind: .code, line: line))
    }

    self.entries = entries.sorted { $0.range.lowerBound < $1.range.lowerBound }
  }

  /// Whether the range starts and ends in plain text, without crossing code.
  ///
  /// Markdown reports columns on a lazy continuation line as if the container's markers were
  /// there, so the end of an expression that spans lines can't be located this way.
  func isProtectable(_ range: Range<String.Index>, in source: String) -> Bool {
    let lower = source.utf8.distance(from: source.startIndex, to: range.lowerBound)
    let upper = source.utf8.distance(from: source.startIndex, to: range.upperBound)

    var index = firstEntry(endingAfter: lower)

    guard index < entries.count,
      entries[index].kind == .plain,
      entries[index].range.contains(lower)
    else {
      return false
    }

    var last = entries[index]

    while index < entries.count, entries[index].range.lowerBound < upper {
      last = entries[index]

      if last.kind == .code {
        return false
      }
      index += 1
    }

    if last.range.contains(upper - 1) {
      return last.kind == .plain
    }
    return source[range].contains(where: \.isLineBreak)
  }

  private func firstEntry(endingAfter offset: Int) -> Int {
    var low = 0
    var high = entries.count

    while low < high {
      let middle = (low + high) / 2

      if entries[middle].range.upperBound > offset {
        high = middle
      } else {
        low = middle + 1
      }
    }
    return low
  }
}

extension Character {
  /// The line endings Markdown counts when it reports source positions.
  fileprivate var isLineBreak: Bool {
    self == "\n" || self == "\r\n" || self == "\r"
  }
}
