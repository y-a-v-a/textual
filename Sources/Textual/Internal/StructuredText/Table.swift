import SwiftUI

// MARK: - Overview
//
// Table uses a two-pass layout system. The first pass renders cells which emit their bounds via
// preferences. The second pass collects all cell bounds, transforms them from anchor coordinates
// to geometry coordinates, and builds a `TableLayout` that the style uses to render overlays
// (such as grid lines) and backgrounds with precise cell positions.

extension StructuredText {
  struct Table: View {
    @Environment(\.tableStyle) private var tableStyle

    @State private var spacing = TableCell.Spacing()

    // The label is rebuilt whenever the cell-spacing preference lands, so the row and column
    // decomposition is memoized rather than derived per evaluation
    @State private var rows =
      Memo<Tuple<AttributedSubstring, PresentationIntent.IntentType?>, [Row]>()

    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring
    private let columns: [PresentationIntent.TableColumn]

    init(
      intent: PresentationIntent.IntentType?,
      content: AttributedSubstring,
      columns: [PresentationIntent.TableColumn]
    ) {
      self.intent = intent
      self.content = content
      self.columns = columns
    }

    var body: some View {
      let configuration = TableStyleConfiguration(
        label: .init(label),
        indentationLevel: indentationLevel
      )
      let resolvedStyle = tableStyle.resolve(configuration: configuration)
        .onPreferenceChange(TableCell.SpacingKey.self) { @MainActor in
          spacing = $0
        }

      AnyView(resolvedStyle)
    }

    @ViewBuilder
    private var label: some View {
      let rows = rows(Tuple(content, intent)) {
        content.blockRuns(parent: intent).map { rowRun in
          Row(
            content: content[rowRun.range],
            columnRuns: content[rowRun.range].blockRuns(parent: rowRun.intent)
          )
        }
      }

      Grid(horizontalSpacing: spacing.horizontal, verticalSpacing: spacing.vertical) {
        ForEach(rows.indices, id: \.self) { rowIndex in
          let row = rows[rowIndex]

          GridRow {
            ForEach(row.columnRuns.indices, id: \.self) { columnIndex in
              let cellRun = row.columnRuns[columnIndex]
              let cellContent = row.content[cellRun.range]

              TableCell(cellContent, row: rowIndex, column: columnIndex)
                .gridColumnAlignment(alignment(for: columnIndex))
            }
          }
        }
      }
    }

    struct Row {
      let content: AttributedSubstring
      let columnRuns: AttributedString.BlockRuns
    }

    private var indentationLevel: Int {
      content.runs.first?.presentationIntent?.indentationLevel ?? 0
    }

    private func alignment(for columnIndex: Int) -> HorizontalAlignment {
      guard columnIndex < columns.count else {
        return .leading
      }

      switch columns[columnIndex].alignment {
      case .left:
        return .leading
      case .center:
        return .center
      case .right:
        return .trailing
      @unknown default:
        return .leading
      }
    }
  }
}
