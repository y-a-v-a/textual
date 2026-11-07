import SwiftUI

extension StructuredText {
  struct TableCell: View {
    @Environment(\.tableCellStyle) private var tableCellStyle

    private let content: Content
    private let identifier: TableCell.Identifier

    init(_ content: Content, row: Int, column: Int) {
      self.content = content
      self.identifier = .init(row: row, column: column)
    }

    var body: some View {
      let configuration = TableCellStyleConfiguration(
        label: .init(label),
        indentationLevel: content.indentationLevel,
        row: identifier.row,
        column: identifier.column
      )
      let resolvedStyle =
        tableCellStyle
        .resolve(configuration: configuration)
        .anchorPreference(key: BoundsKey.self, value: .bounds) { anchor in
          [identifier: anchor]
        }

      AnyView(resolvedStyle)
    }

    private var label: some View {
      WithInlineStyle(content.text) {
        TextFragment($0)
      }
    }
  }
}

extension StructuredText.TableCell {
  // A cell's text and indentation level, derived once when the table's content changes
  struct Content: Equatable {
    let text: AttributedString
    let indentationLevel: Int

    init(_ content: AttributedSubstring) {
      self.text = AttributedString(content)
      self.indentationLevel = content.runs.first?.presentationIntent?.indentationLevel ?? 0
    }
  }
}

extension StructuredText.TableCell {
  struct Identifier: Hashable {
    let row: Int
    let column: Int
  }

  struct BoundsKey: PreferenceKey {
    static let defaultValue: [Identifier: Anchor<CGRect>] = [:]

    static func reduce(
      value: inout [Identifier: Anchor<CGRect>],
      nextValue: () -> [Identifier: Anchor<CGRect>]
    ) {
      value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
  }
}

extension StructuredText.TableCell {
  struct Spacing: Sendable, Hashable {
    let horizontal: CGFloat?
    let vertical: CGFloat?

    init(horizontal: CGFloat? = nil, vertical: CGFloat? = nil) {
      self.horizontal = horizontal
      self.vertical = vertical
    }
  }

}

extension EnvironmentValues {
  @Entry var tableCellSpacing = StructuredText.TableCell.Spacing()
}
