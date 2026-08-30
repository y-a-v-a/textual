import Foundation

// MARK: - Overview
//
// SynchronousCodeTokenizer tokenizes code on the main actor, while a view body is being
// evaluated. It backs `SyntaxHighlightingMode.synchronous`, which offscreen renderers use
// because they never give asynchronous tokenization a chance to reach the drawing pass.
//
// Results are memoized in the CodeTokenCache shared with the asynchronous tokenizer.
// Offscreen renderers typically evaluate the same body several times, and paginated
// output re-renders the same code blocks once per page.

@MainActor
enum SynchronousCodeTokenizer {
  private static let tokenizer = PrismTokenizer()

  /// Tokenizes `code`, reusing a previous result when one is available.
  ///
  /// Returns a single plain token when there is no language hint or no tokenizer.
  static func tokenize(code: String, language: String?) -> [CodeToken] {
    guard let tokenizer, let language else {
      return [CodeToken(content: code, type: .plain)]
    }

    if let tokens = CodeTokenCache.shared.tokens(code: code, language: language) {
      return tokens
    }

    let tokens = tokenizer.tokenize(code: code, language: language)
    CodeTokenCache.shared.store(tokens, code: code, language: language)
    return tokens
  }
}
