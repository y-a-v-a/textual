import Foundation

extension Formatter {
  func plainText() -> String {
    blockNodes.renderPlainText(startsInsideBlock: startsInsideBlock)
  }
}

// MARK: - Inline rendering

extension Formatter.InlineNode {
  fileprivate func renderPlainText() -> String {
    switch self {
    case .text(let text):
      return text
    case .code(let code):
      return code
    case .strong(let children):
      return children.renderPlainText()
    case .emphasized(let children):
      return children.renderPlainText()
    case .strikethrough(let children):
      return children.renderPlainText()
    case .link(_, let children):
      return children.renderPlainText()
    case .lineBreak:
      return " "
    case .attachment(let attachment):
      return attachment.description
    }
  }
}

extension Array where Element == Formatter.InlineNode {
  fileprivate func renderPlainText() -> String {
    self.map {
      $0.renderPlainText()
    }.joined()
  }
}

// MARK: - Block rendering

// When the text starts inside a block, the first line continues a line that began before the text
// did, so nothing that leads that line (indentation, list markers) is part of the text.

extension Formatter.BlockNode {
  fileprivate func renderPlainText(
    indentationLevel: Int,
    tightSpacing: Bool,
    startsInsideBlock: Bool
  ) -> String {
    switch self {
    case .paragraph(let children):
      return children.renderPlainText()
        .indented(indentationLevel, skippingFirstLine: startsInsideBlock)
    case .header(_, let children):
      return children.renderPlainText()
        .indented(indentationLevel, skippingFirstLine: startsInsideBlock)
    case .orderedList(let children):
      return children.renderOrderedPlainText(
        indentationLevel: indentationLevel + 1, startsInsideBlock: startsInsideBlock)
    case .unorderedList(let children):
      return children.renderUnorderedPlainText(
        indentationLevel: indentationLevel + 1, startsInsideBlock: startsInsideBlock)
    case .codeBlock(_, let code):
      return code.indented(indentationLevel, skippingFirstLine: startsInsideBlock)
    case .blockQuote(let children):
      return children.renderPlainText(
        indentationLevel: indentationLevel + 1, tightSpacing: tightSpacing,
        startsInsideBlock: startsInsideBlock)
    case .table(_, let children):
      return children.renderPlainText(indentationLevel: indentationLevel)
    case .thematicBreak:
      return "***"
    }
  }
}

extension Array where Element == Formatter.BlockNode {
  fileprivate func renderPlainText(
    indentationLevel: Int = 0,
    tightSpacing: Bool = false,
    startsInsideBlock: Bool = false
  ) -> String {
    self.enumerated().map { index, block in
      block.renderPlainText(
        indentationLevel: indentationLevel, tightSpacing: tightSpacing,
        startsInsideBlock: startsInsideBlock && index == 0)
    }.joined(separator: tightSpacing ? "\n" : "\n\n")
  }
}

// MARK: - Table rendering

extension Formatter.TableRow {
  fileprivate func renderPlainText(indentationLevel: Int = 0) -> String {
    cells.map {
      $0.renderPlainText().csvEscaped()
    }
    .joined(separator: ",")
    .indented(indentationLevel)
  }
}

extension Array where Element == Formatter.TableRow {
  fileprivate func renderPlainText(indentationLevel: Int = 0) -> String {
    self.map {
      $0.renderPlainText(indentationLevel: indentationLevel)
    }.joined(separator: "\n")
  }
}

// MARK: - List rendering

extension Formatter.ListItem {
  fileprivate func renderOrderedPlainText(indentationLevel: Int, startsInsideBlock: Bool)
    -> String
  {
    renderPlainText(
      marker: "\(ordinal). ", indentationLevel: indentationLevel,
      startsInsideBlock: startsInsideBlock)
  }

  fileprivate func renderUnorderedPlainText(indentationLevel: Int, startsInsideBlock: Bool)
    -> String
  {
    renderPlainText(
      marker: "• ", indentationLevel: indentationLevel, startsInsideBlock: startsInsideBlock)
  }

  private func renderPlainText(marker: String, indentationLevel: Int, startsInsideBlock: Bool)
    -> String
  {
    let text = blocks.renderPlainText(
      indentationLevel: indentationLevel, tightSpacing: true, startsInsideBlock: startsInsideBlock)

    // The item started before the text did, so its marker is not part of it
    guard !startsInsideBlock else {
      return text
    }

    return text.prefixed(with: marker, indentationLevel: indentationLevel)
  }
}

extension Array where Element == Formatter.ListItem {
  fileprivate func renderOrderedPlainText(indentationLevel: Int, startsInsideBlock: Bool)
    -> String
  {
    self.enumerated().map { index, item in
      item.renderOrderedPlainText(
        indentationLevel: indentationLevel, startsInsideBlock: startsInsideBlock && index == 0)
    }.joined(separator: "\n")
  }

  fileprivate func renderUnorderedPlainText(indentationLevel: Int, startsInsideBlock: Bool)
    -> String
  {
    self.enumerated().map { index, item in
      item.renderUnorderedPlainText(
        indentationLevel: indentationLevel, startsInsideBlock: startsInsideBlock && index == 0)
    }.joined(separator: "\n")
  }
}

extension String {
  fileprivate func indented(_ level: Int, skippingFirstLine: Bool = false) -> String {
    guard level > 0 else { return self }

    let indent = String(repeating: "  ", count: level)
    let indented =
      self
      .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
      .enumerated()
      .map { index, line in
        skippingFirstLine && index == 0 ? String(line) : indent + line
      }
      .joined(separator: "\n")
    return self.hasSuffix("\n") ? indented + "\n" : indented
  }

  fileprivate func prefixed(with prefix: String, indentationLevel: Int) -> String {
    let indent = String(repeating: "  ", count: indentationLevel)

    let firstLineEnd = self.firstIndex(where: \.isNewline) ?? self.endIndex
    var firstLine = self[..<firstLineEnd]
    let rest = self[firstLineEnd...]  // includes the newline if present

    if indentationLevel > 0, firstLine.hasPrefix(indent) {
      firstLine = firstLine.dropFirst(indent.count)
    }

    return indent + prefix + firstLine + rest
  }

  fileprivate func csvEscaped() -> String {
    // Quick edge-space check without scanning the whole string
    var needsQuoting =
      (self.unicodeScalars.first?.value == 0x20) || (self.unicodeScalars.last?.value == 0x20)

    // Scan once over UTF-8 to detect commas, quotes, or newlines
    var needsDoubling = false
    for b in self.utf8 {
      switch b {
      case 0x2C:  // ,
        needsQuoting = true
      case 0x22:  // "
        needsQuoting = true
        needsDoubling = true
      case 0x0A,  // \n
        0x0D:  // \r
        needsQuoting = true
      default:
        break
      }
    }

    if !needsQuoting {
      return self
    }

    // If we need quotes but there are no double quotes inside, just wrap
    if !needsDoubling {
      return "\"\(self)\""
    }

    // Otherwise, build once with doubled quotes.
    var out = String()
    out.reserveCapacity(self.utf8.count + 2)  // rough lower bound
    out.append("\"")
    for ch in self {
      if ch == "\"" {
        out.append("\"\"")
      } else {
        out.append(ch)
      }
    }
    out.append("\"")

    return out
  }
}
