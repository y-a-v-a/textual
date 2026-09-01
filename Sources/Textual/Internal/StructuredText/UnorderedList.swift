import SwiftUI

extension StructuredText {
  struct UnorderedList: View {
    @Environment(\.listItemSpacing) private var listItemSpacing
    @Environment(\.textEnvironment) private var textEnvironment

    // Cached as self-contained slices, not indices into `content`: the memo hits on content
    // equality even when the backing string changed (a streamed re-parse)
    @State private var blockSlices =
      Memo<Tuple<AttributedSubstring, PresentationIntent.IntentType?>, [AttributedString.BlockSlice]>()

    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring

    init(intent: PresentationIntent.IntentType?, content: AttributedSubstring) {
      self.intent = intent
      self.content = content
    }

    var body: some View {
      let slices = blockSlices(Tuple(content, intent)) {
        content.blockSlices(parent: intent)
      }

      BlockVStack {
        ForEach(slices.indices, id: \.self) { index in
          let slice = slices[index]

          UnorderedListItem(
            intent: slice.intent,
            content: slice.content
          )
        }
      }
      .environment(\.resolvedListItemSpacing, listItemSpacing.resolve(in: textEnvironment))
      .environment(\.listItemSpacingEnabled, true)
    }
  }
}

extension StructuredText {
  fileprivate struct UnorderedListItem: View {
    @Environment(\.listItemStyle) private var listItemStyle
    @Environment(\.unorderedListMarker) private var unorderedListMarker
    @Environment(\.taskListMarker) private var taskListMarker

    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring

    init(
      intent: PresentationIntent.IntentType?,
      content: AttributedSubstring
    ) {
      self.intent = intent
      self.content = content
    }

    var body: some View {
      // A task list item renders a checkbox in place of the bullet, and drops the `[ ]` marker
      // from the text it displays
      let taskListItem = content.taskListItem
      let configuration = ListItemStyleConfiguration(
        marker: .init(marker(for: taskListItem)),
        block: .init(
          BlockContent(
            parent: intent,
            content: taskListItem?.content ?? content
          )
        ),
        indentationLevel: indentationLevel
      )
      let resolvedStyle = listItemStyle.resolve(configuration: configuration)

      AnyView(resolvedStyle)
    }

    private func marker(for taskListItem: TaskListItem?) -> some View {
      if let taskListItem {
        AnyView(
          taskListMarker.resolve(
            configuration: .init(
              indentationLevel: indentationLevel,
              isCompleted: taskListItem.isCompleted
            )
          )
        )
      } else {
        AnyView(
          unorderedListMarker.resolve(
            configuration: .init(
              indentationLevel: indentationLevel
            )
          )
        )
      }
    }

    private var indentationLevel: Int {
      content.runs.first?.presentationIntent?.indentationLevel ?? 0
    }
  }
}
