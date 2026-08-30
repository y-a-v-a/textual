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

    try await Task.sleep(for: .milliseconds(100))

    #expect(runs == ["first", "third"])
  }

  @Test func isolatedCallsEachRunImmediately() async throws {
    let throttle = Throttle(interval: .milliseconds(10))
    var runs: [String] = []

    throttle.schedule { runs.append("first") }
    try await Task.sleep(for: .milliseconds(100))
    throttle.schedule { runs.append("second") }

    #expect(runs == ["first", "second"])
  }
}
