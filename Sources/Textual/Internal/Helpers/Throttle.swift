import Foundation

// MARK: - Overview
//
// Throttle coalesces bursts of work. The first call in a quiet period runs immediately —
// an isolated change pays no added latency — and calls arriving inside the cooldown window
// only replace the pending operation, which runs once at the end of the window.
//
// StructuredText and InlineText use it to re-parse markup: streaming content appends many
// times per second, and parsing is proportional to the whole document, so parsing every
// append makes the total work quadratic. Throttled, the parse rate is bounded while the
// latest content is always parsed eventually.

@MainActor
final class Throttle {
  private let interval: Duration
  private var pending: (() -> Void)?
  private var cooldown: Task<Void, Never>?

  /// Creates a throttle whose cooldown window lasts `interval`.
  init(interval: Duration = .milliseconds(50)) {
    self.interval = interval
  }

  /// Runs `operation` now, or — inside the cooldown window — once the window ends.
  ///
  /// Only the most recent operation scheduled during a window survives it.
  func schedule(_ operation: @escaping () -> Void) {
    guard cooldown == nil else {
      pending = operation
      return
    }

    operation()

    cooldown = Task { [weak self, interval] in
      try? await Task.sleep(for: interval)

      guard let self, !Task.isCancelled else {
        return
      }

      self.cooldown = nil

      if let pending = self.pending {
        self.pending = nil
        self.schedule(pending)
      }
    }
  }

  deinit {
    cooldown?.cancel()
  }
}
