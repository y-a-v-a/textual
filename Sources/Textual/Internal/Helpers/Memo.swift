import Foundation

// MARK: - Overview
//
// Memo caches the result of a pure derivation keyed on an Equatable input. Held in @State,
// it lets a view derive a value inside `body` while paying the computation only when the
// input actually changes — environment-driven body evaluations reuse the previous result.
// Mutating the memo during a body evaluation is safe because its contents are not observed
// state, so no view update is triggered.

final class Memo<Input: Equatable, Value> {
  private var input: Input?
  private var value: Value?

  func callAsFunction(_ input: Input, _ compute: () -> Value) -> Value {
    if let value, self.input == input {
      return value
    }

    let value = compute()
    self.input = input
    self.value = value
    return value
  }
}
