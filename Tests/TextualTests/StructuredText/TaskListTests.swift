#if os(iOS) && !targetEnvironment(macCatalyst)
  import SnapshotTesting
  import SwiftUI
  import Testing

  import Textual

  extension StructuredText {
    @MainActor
    struct TaskListTests {
      private let layout = SwiftUISnapshotLayout.device(config: .iPhone8)

      @Test func taskList() {
        let view = StructuredText(
          markdown: """
            - [ ] Pack the sandwiches
            - [x] Fill the thermos
            - [X] Check the map
            - Not a task at all
            """
        )
        .background(Color.guide)
        .padding(.horizontal)

        assertSnapshot(of: view, as: .textualImage(layout: layout))
      }

      @Test func nestedTaskList() {
        let view = StructuredText(
          markdown: """
            - [x] Plan the trip
              - [x] Pick a date
              - [ ] Book the hotel
                - [ ] Compare prices
            - [ ] Pack
            """
        )
        .background(Color.guide)
        .padding(.horizontal)

        assertSnapshot(of: view, as: .textualImage(layout: layout))
      }

      @Test func looseTaskList() {
        let view = StructuredText(
          markdown: """
            - [ ] Pack the sandwiches

              Rye bread, if there is any left.

            - [x] Fill the thermos
            """
        )
        .background(Color.guide)
        .padding(.horizontal)

        assertSnapshot(of: view, as: .textualImage(layout: layout))
      }

      @Test func markersStayLiteralWhereTheyAreNotTaskItems() {
        let view = StructuredText(
          markdown: """
            [ ] This paragraph is not a list item.

            - `[ ]` An inline code marker stays literal.
            - [ ]No space after the marker.

            ```
            - [x] So does a marker in a code block.
            ```
            """
        )
        .background(Color.guide)
        .padding(.horizontal)

        assertSnapshot(of: view, as: .textualImage(layout: layout))
      }

      @Test func customTaskListMarker() {
        let view = StructuredText(
          markdown: """
            - [ ] Pack the sandwiches
            - [x] Fill the thermos
            """
        )
        .background(Color.guide)
        .padding(.horizontal)
        .textual.taskListMarker(
          .checkbox(
            incompleteSymbolName: "circle",
            completeSymbolName: "checkmark.circle.fill"
          )
        )

        assertSnapshot(of: view, as: .textualImage(layout: layout))
      }
    }
  }
#endif
