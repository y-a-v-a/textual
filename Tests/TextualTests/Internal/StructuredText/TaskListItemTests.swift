import Foundation
import Testing

@testable import Textual

struct TaskListItemTests {
  @Test func incompleteMarker() throws {
    let items = try taskListItems(in: "- [ ] Take out the trash")

    #expect(items.count == 1)
    #expect(items.first??.isCompleted == false)
    #expect(text(items.first ?? nil) == "Take out the trash")
  }

  @Test func completeMarker() throws {
    let items = try taskListItems(in: "- [x] Take out the trash")

    #expect(items.first??.isCompleted == true)
    #expect(text(items.first ?? nil) == "Take out the trash")
  }

  @Test func uppercaseCompleteMarker() throws {
    let items = try taskListItems(in: "- [X] Take out the trash")

    #expect(items.first??.isCompleted == true)
    #expect(text(items.first ?? nil) == "Take out the trash")
  }

  @Test func emptyTaskItem() throws {
    let items = try taskListItems(in: "- [ ]")

    #expect(items.first??.isCompleted == false)
    #expect(text(items.first ?? nil) == "")
  }

  @Test func markerKeepsFollowingInlineFormatting() throws {
    let items = try taskListItems(in: "- [x] Take out the **trash**")

    #expect(items.first??.isCompleted == true)
    #expect(text(items.first ?? nil) == "Take out the trash")
  }

  @Test func continuationParagraphsAreLeftAlone() throws {
    let items = try taskListItems(
      in: """
        - [ ] Take out the trash

          [x] This is not a marker
        """
    )

    #expect(items.count == 1)
    #expect(items.first??.isCompleted == false)
    #expect(text(items.first ?? nil)?.contains("[x] This is not a marker") == true)
  }

  @Test func multipleItems() throws {
    let items = try taskListItems(
      in: """
        - [ ] Take out the trash
        - [x] Water the plants
        - Buy milk
        """
    )

    #expect(items.count == 3)
    #expect(items[0]?.isCompleted == false)
    #expect(items[1]?.isCompleted == true)
    #expect(items[2] == nil)
  }

  @Test(
    arguments: [
      // A plain list item
      "- Take out the trash",
      // The marker has to be literal text
      "- `[ ]` Take out the trash",
      "- **[x]** Take out the trash",
      "- [x](https://example.com) Take out the trash",
      // The marker has to be separated from the item text
      "- [ ]Take out the trash",
      // Neither whitespace nor `x`
      "- [y] Take out the trash",
      // Not a marker at all
      "- [] Take out the trash",
      "- ] Take out the trash",
      "- [ Take out the trash",
    ]
  )
  func nonTaskItems(markdown: String) throws {
    let items = try taskListItems(in: markdown)

    #expect(items.count == 1)
    #expect(items.first ?? nil == nil)
  }

  // MARK: - Helpers

  private func taskListItems(in markdown: String) throws -> [StructuredText.TaskListItem?] {
    let document = try AttributedString(
      markdown: markdown,
      including: \.textual,
      options: .init(interpretedSyntax: .full)
    )

    var items: [StructuredText.TaskListItem?] = []

    for block in document.blockRuns() {
      guard case .unorderedList = block.intent?.kind else { continue }

      let list = document[block.range]

      for item in list.blockRuns(parent: block.intent) {
        items.append(list[item.range].taskListItem)
      }
    }

    return items
  }

  private func text(_ item: StructuredText.TaskListItem?) -> String? {
    item.map { String($0.content.characters[...]) }
  }
}
