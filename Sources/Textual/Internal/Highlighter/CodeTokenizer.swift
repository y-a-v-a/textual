import Foundation

// MARK: - Overview
//
// CodeTokenizer tokenizes code off the main actor. The actor isolation keeps the
// underlying PrismTokenizer, which wraps a JavaScriptCore context, away from concurrent
// access.
//
// Views that highlight while their body is evaluated use SynchronousCodeTokenizer
// instead.

actor CodeTokenizer {
  private let tokenizer: PrismTokenizer

  static let shared = CodeTokenizer()

  init?() {
    guard let tokenizer = PrismTokenizer() else {
      return nil
    }
    self.tokenizer = tokenizer
  }

  func tokenize(code: String, language: String) -> [CodeToken] {
    tokenizer.tokenize(code: code, language: language)
  }
}
