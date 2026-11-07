// Mac Catalyst is excluded because `UIWindow` cannot be created in the test host.
#if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
  import SwiftUI
  import Testing

  import Textual

  extension StructuredText {
    @MainActor
    struct TableCellSpacingTests {
      private static let markdown = """
        | Command | Description |
        | --- | --- |
        | `git status` | List all new or modified files |
        | `git diff` | Show file differences that haven't been staged |
        | `git log` | Show the commit history |
        """

      // A table style sets the spacing on its label, and the grid inside the label applies it
      @Test func tableStyleSetsTheSpacingBetweenRows() {
        let compact = Self.height(of: StructuredText(markdown: Self.markdown), rowSpacing: 0)
        let spaced = Self.height(of: StructuredText(markdown: Self.markdown), rowSpacing: 30)

        // Four rows, three gaps between them
        #expect(abs(spaced - compact - 90) < 0.5)
      }

      private static func height(of view: some View, rowSpacing: CGFloat) -> CGFloat {
        let content = view.textual.tableStyle(SpacedTableStyle(rowSpacing: rowSpacing))
        let proposal = CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)

        #if canImport(UIKit)
          return UIHostingController(rootView: content).sizeThatFits(in: proposal).height
        #else
          return NSHostingController(rootView: content).sizeThatFits(in: proposal).height
        #endif
      }
    }
  }

  private struct SpacedTableStyle: StructuredText.TableStyle {
    let rowSpacing: CGFloat

    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .textual.tableCellSpacing(horizontal: 0, vertical: rowSpacing)
    }
  }
#endif
