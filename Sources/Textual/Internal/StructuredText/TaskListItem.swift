import Foundation

// MARK: - Overview
//
// GitHub-flavored Markdown marks a list item as a task by starting its first paragraph with
// `[ ]`, `[x]`, or `[X]`. Foundation's Markdown parser does not recognize those markers, so they
// survive parsing as literal text at the start of the list item.
//
// TaskListItem reads such a marker back out at render time. Keeping the marker in the parsed
// content — rather than rewriting it during parsing — means copied text still round-trips as
// Markdown, and it keeps detection where the surrounding block structure is known.

extension StructuredText {
  /// A task list item marker read from the start of a list item.
  struct TaskListItem {
    /// Whether the task is completed.
    let isCompleted: Bool
    /// The list item content, with the marker removed.
    let content: AttributedSubstring
  }
}

extension AttributedSubstring {
  /// Reads a task list item marker from the start of this list item's content.
  ///
  /// Returns `nil` when the content does not start with a marker. The marker only counts as one
  /// when it is literal text: markers inside inline code, emphasis, links, or attachments are
  /// left alone, matching GitHub-flavored Markdown.
  var taskListItem: StructuredText.TaskListItem? {
    guard let run = runs.first,
      run.inlinePresentationIntent?.isEmpty ?? true,
      run.link == nil,
      run.textual.attachment == nil,
      // An escaped marker (`\[ ]`) parses to the same text as a real one; the parser tags it
      run.textual.escapedTaskListMarker != true
    else {
      return nil
    }

    let characters = self.characters
    var index = characters.startIndex

    // The marker itself has to sit inside the first run, or it is not literal text
    func nextMarkerCharacter() -> Character? {
      guard index < run.range.upperBound, index < characters.endIndex else { return nil }
      defer { index = characters.index(after: index) }
      return characters[index]
    }

    guard nextMarkerCharacter() == "[",
      let state = nextMarkerCharacter(),
      nextMarkerCharacter() == "]"
    else {
      return nil
    }

    let isCompleted: Bool

    switch state {
    case "x", "X":
      isCompleted = true
    case let state where state.isWhitespace:
      isCompleted = false
    default:
      return nil
    }

    // A marker is separated from the item text by whitespace, unless the item is empty
    if index < characters.endIndex {
      guard characters[index].isWhitespace else { return nil }
      index = characters.index(after: index)
    }

    return .init(isCompleted: isCompleted, content: self[index...])
  }
}
