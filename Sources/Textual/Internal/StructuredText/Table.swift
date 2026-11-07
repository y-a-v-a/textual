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

    @State private var cells = Cells()

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

      AnyView(resolvedStyle)
    }

    private var label: some View {
      TableFittingLayout {
        TableGrid(
          rows: cells(content, intent: intent),
          alignments: columns.map(\.horizontalAlignment)
        )
      }
    }

    private var indentationLevel: Int {
      content.runs.first?.presentationIntent?.indentationLevel ?? 0
    }
  }

  // Derives the table's cells once per content change rather than per evaluation, which would
  // otherwise rescan every run of the table and copy every cell into a fresh `AttributedString`.
  //
  // A cell whose content is unchanged keeps its previous value, so a view that holds it compares
  // equal and is not evaluated again. While a table streams in, only the cells that changed are.
  private final class Cells {
    private var input: Tuple<AttributedSubstring, PresentationIntent.IntentType?>?
    private var rows: [[TableCell.Content]] = []

    func callAsFunction(
      _ content: AttributedSubstring,
      intent: PresentationIntent.IntentType?
    ) -> [[TableCell.Content]] {
      let input = Tuple(content, intent)
      if self.input == input {
        return rows
      }

      let previous = rows
      rows = content.blockRuns(parent: intent).enumerated().map { rowIndex, rowRun in
        let row = content[rowRun.range]
        return row.blockRuns(parent: rowRun.intent).enumerated().map { columnIndex, cellRun in
          let cell = TableCell.Content(row[cellRun.range])
          guard
            rowIndex < previous.count,
            columnIndex < previous[rowIndex].count,
            previous[rowIndex][columnIndex] == cell
          else {
            return cell
          }
          return previous[rowIndex][columnIndex]
        }
      }
      self.input = input
      return rows
    }
  }

  // The grid reads the cell spacing from the environment, which the table style sets on the
  // label. Read there, it applies on the first layout pass; sent up as a preference into the
  // table's state, it would only apply on a second pass, laying every table out twice.
  private struct TableGrid: View {
    @Environment(\.tableCellSpacing) private var spacing

    let rows: [[TableCell.Content]]
    let alignments: [HorizontalAlignment]

    var body: some View {
      Grid(horizontalSpacing: spacing.horizontal, verticalSpacing: spacing.vertical) {
        ForEach(rows.indices, id: \.self) { rowIndex in
          GridRow {
            ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
              TableCell(rows[rowIndex][columnIndex], row: rowIndex, column: columnIndex)
                .gridColumnAlignment(alignment(for: columnIndex))
            }
          }
        }
      }
    }

    private func alignment(for columnIndex: Int) -> HorizontalAlignment {
      columnIndex < alignments.count ? alignments[columnIndex] : .leading
    }
  }

  // A table that fits lays out at its ideal width. The grid is proposed that width whenever the
  // table fits, rather than the width its parent proposes, for two reasons:
  //
  // - A grid lays out every cell again for each new width it is proposed, even when the table
  //   fits all of them. Its parent proposes the container width to measure the table, then the
  //   table's own width to place it.
  // - The table's ideal width is fractional, and a parent that places the table at that width
  //   proposes it back rounded to the pixel grid, a fraction of a point short. Proposed less than
  //   its ideal width, the grid shrinks a column below its ideal, so that column's text wraps and
  //   every cell lays out again.
  //
  // Proposals within a point of the ideal width count as fitting, which covers that rounding at
  // the cost of overflowing the proposal by less than a point.
  private struct TableFittingLayout: Layout {
    private static let tolerance: CGFloat = 1

    func sizeThatFits(
      proposal: ProposedViewSize,
      subviews: Subviews,
      cache: inout ()
    ) -> CGSize {
      guard let subview = subviews.first else {
        return .zero
      }
      return subview.sizeThatFits(gridProposal(for: proposal, subview: subview))
    }

    func placeSubviews(
      in bounds: CGRect,
      proposal: ProposedViewSize,
      subviews: Subviews,
      cache: inout ()
    ) {
      guard let subview = subviews.first else {
        return
      }
      subview.place(
        at: bounds.origin,
        anchor: .topLeading,
        proposal: gridProposal(for: proposal, subview: subview)
      )
    }

    // Forward the grid's guides, such as its first text baseline, which a list item marker
    // aligns to when a table opens the item
    func explicitAlignment(
      of guide: VerticalAlignment,
      in bounds: CGRect,
      proposal: ProposedViewSize,
      subviews: Subviews,
      cache: inout ()
    ) -> CGFloat? {
      guard let subview = subviews.first else {
        return nil
      }
      let dimensions = subview.dimensions(in: gridProposal(for: proposal, subview: subview))
      return dimensions[explicit: guide].map { bounds.minY + $0 }
    }

    func explicitAlignment(
      of guide: HorizontalAlignment,
      in bounds: CGRect,
      proposal: ProposedViewSize,
      subviews: Subviews,
      cache: inout ()
    ) -> CGFloat? {
      guard let subview = subviews.first else {
        return nil
      }
      let dimensions = subview.dimensions(in: gridProposal(for: proposal, subview: subview))
      return dimensions[explicit: guide].map { bounds.minX + $0 }
    }

    private func gridProposal(
      for proposal: ProposedViewSize,
      subview: LayoutSubview
    ) -> ProposedViewSize {
      guard let width = proposal.width, width.isFinite else {
        return proposal
      }

      let ideal = ProposedViewSize(width: nil, height: proposal.height)
      let idealWidth = subview.sizeThatFits(ideal).width

      return width + Self.tolerance >= idealWidth ? ideal : proposal
    }
  }
}

extension PresentationIntent.TableColumn {
  fileprivate var horizontalAlignment: HorizontalAlignment {
    switch alignment {
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
