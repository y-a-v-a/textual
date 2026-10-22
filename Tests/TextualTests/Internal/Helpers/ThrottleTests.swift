import Foundation
import Testing

@testable import Textual

@MainActor
struct ThrottleTests {
  @Test func firstCallRunsImmediately() {
    let throttle = Throttle(interval: .milliseconds(10))
    var ran = false

    throttle.schedule { ran = true }

    #expect(ran)
  }

  @Test func callsInsideTheWindowCoalesceToTheLatest() async throws {
    let throttle = Throttle(interval: .milliseconds(10))
    var runs: [String] = []

    throttle.schedule { runs.append("first") }
    throttle.schedule { runs.append("second") }
    throttle.schedule { runs.append("third") }

    #expect(runs == ["first"])

    try await waitUntil { runs.count == 2 }

    #expect(runs == ["first", "third"])
  }

  @Test func isolatedCallsEachRunImmediately() async throws {
    let throttle = Throttle(interval: .milliseconds(10))
    var runs: [String] = []

    throttle.schedule { runs.append("first") }
    try await waitUntil { !throttle.isCoolingDown }
    throttle.schedule { runs.append("second") }

    #expect(runs == ["first", "second"])
  }

  // The window ends on the main actor, which other tests can keep busy for longer than a fixed
  // wait, so wait for the outcome instead. The limit counts turns on the main actor rather than
  // time, because no turn passes while another test holds it.
  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 where !condition() {
      try await Task.sleep(for: .milliseconds(5))
    }
  }
}
