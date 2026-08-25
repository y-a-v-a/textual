import SwiftUI

extension StructuredText {
  /// The properties of a task-list marker passed to a `TaskListMarker`.
  public struct TaskListMarkerConfiguration {
    /// The indentation level of the list within the document structure.
    public let indentationLevel: Int
    /// Whether the task is completed.
    public let isCompleted: Bool
  }

  /// A marker view used for task list items (for example, a checkbox).
  ///
  /// `StructuredText` renders a GitHub-flavored Markdown task list item — a list item whose text
  /// starts with `[ ]`, `[x]`, or `[X]` — with this marker instead of the usual bullet.
  ///
  /// You can apply a task list marker using the ``TextualNamespace/taskListMarker(_:)`` modifier
  /// or through a bundled ``StructuredText/Style``.
  public protocol TaskListMarker: DynamicProperty {
    associatedtype Body: View

    /// Creates a view that represents the marker for a task list item.
    @MainActor @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body

    typealias Configuration = TaskListMarkerConfiguration
  }
}

extension EnvironmentValues {
  @usableFromInline
  @Entry var taskListMarker: any StructuredText.TaskListMarker = .checkbox
}

// MARK: - Symbol

extension StructuredText {
  /// A task list marker that uses SF Symbols.
  public struct SymbolTaskListMarker: TaskListMarker {
    private let incompleteSymbolName: String
    private let completeSymbolName: String
    private let scale: CGFloat
    private let minWidth: FontScaled<CGFloat>

    /// Creates a symbol task list marker.
    ///
    /// - Parameters:
    ///   - incompleteSymbolName: The SF Symbol name used for incomplete tasks.
    ///   - completeSymbolName: The SF Symbol name used for completed tasks.
    ///   - scale: A font scale applied to the symbol.
    ///   - minWidth: A font-relative minimum width for the marker.
    public init(
      incompleteSymbolName: String,
      completeSymbolName: String,
      scale: CGFloat = 0.9,
      minWidth: FontScaled<CGFloat> = .fontScaled(1.5)
    ) {
      self.incompleteSymbolName = incompleteSymbolName
      self.completeSymbolName = completeSymbolName
      self.scale = scale
      self.minWidth = minWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
      SwiftUI.Image(
        systemName: configuration.isCompleted ? completeSymbolName : incompleteSymbolName
      )
      .textual.fontScale(scale)
      .textual.frame(minWidth: minWidth, alignment: .trailing)
    }
  }
}

extension StructuredText.TaskListMarker where Self == StructuredText.SymbolTaskListMarker {
  /// A checkbox marker: an empty square for incomplete tasks, a checked square for completed ones.
  public static var checkbox: Self {
    .init(incompleteSymbolName: "square", completeSymbolName: "checkmark.square")
  }

  /// A checkbox marker that uses custom SF Symbols.
  ///
  /// - Parameters:
  ///   - incompleteSymbolName: The SF Symbol name used for incomplete tasks.
  ///   - completeSymbolName: The SF Symbol name used for completed tasks.
  ///   - scale: A font scale applied to the symbol.
  ///   - minWidth: A font-relative minimum width for the marker.
  public static func checkbox(
    incompleteSymbolName: String,
    completeSymbolName: String,
    scale: CGFloat = 0.9,
    minWidth: FontScaled<CGFloat> = .fontScaled(1.5)
  ) -> Self {
    .init(
      incompleteSymbolName: incompleteSymbolName,
      completeSymbolName: completeSymbolName,
      scale: scale,
      minWidth: minWidth
    )
  }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
#Preview("TaskList") {
  StructuredText(
    markdown: """
      - [x] Plan the trip
        - [x] Pick a date
        - [ ] Book the hotel
      - [ ] Pack the sandwiches
      - Not a task at all
      """
  )
  .padding()
  .textual.textSelection(.enabled)
}
