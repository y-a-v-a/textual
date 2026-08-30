import SwiftUI

extension StructuredText {
  // NB: Enables environment resolution in `TaskListMarker`
  struct ResolvedTaskListMarker<M: TaskListMarker>: View {
    private let marker: M
    private let configuration: M.Configuration

    init(_ marker: M, configuration: M.Configuration) {
      self.marker = marker
      self.configuration = configuration
    }

    var body: M.Body {
      marker.makeBody(configuration: configuration)
    }
  }
}

extension StructuredText.TaskListMarker {
  @MainActor func resolve(configuration: Configuration) -> some View {
    StructuredText.ResolvedTaskListMarker(self, configuration: configuration)
  }
}
