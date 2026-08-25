import SwiftUI

extension StructuredText {
  struct UnorderedList: View {
    @Environment(\.listItemSpacing) private var listItemSpacing
    @Environment(\.textEnvironment) private var textEnvironment

    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring

    init(intent: PresentationIntent.IntentType?, content: AttributedSubstring) {
      self.intent = intent
      self.content = content
    }

    var body: some View {
      let runs = content.blockRuns(parent: intent)

      BlockVStack {
        ForEach(runs.indices, id: \.self) { index in
          let run = runs[index]

          UnorderedListItem(
            intent: run.intent,
            content: content[run.range]
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
