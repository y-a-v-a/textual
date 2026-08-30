import Foundation
import Testing

@testable import Textual

struct MemoTests {
  @Test func computesOncePerInput() {
    let memo = Memo<Int, String>()
    var computations = 0

    let first = memo(1) {
      computations += 1
      return "one"
    }
    let second = memo(1) {
      computations += 1
      return "one again"
    }

    #expect(first == "one")
    #expect(second == "one")
    #expect(computations == 1)
  }

  @Test func recomputesWhenTheInputChanges() {
    let memo = Memo<Int, String>()

    #expect(memo(1) { "one" } == "one")
    #expect(memo(2) { "two" } == "two")
    // Only the last input is kept
    #expect(memo(1) { "recomputed" } == "recomputed")
  }
}
