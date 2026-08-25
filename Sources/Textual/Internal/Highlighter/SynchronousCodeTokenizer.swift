import Foundation

// MARK: - Overview
//
// SynchronousCodeTokenizer tokenizes code on the main actor, while a view body is being
// evaluated. It backs `SyntaxHighlightingMode.synchronous`, which offscreen renderers use
// because they never give asynchronous tokenization a chance to reach the drawing pass.
//
// Tokens are a pure function of the code and its language, so results are memoized in a
// bounded cache. Offscreen renderers typically evaluate the same body several times, and
// paginated output re-renders the same code blocks once per page.

@MainActor
enum SynchronousCodeTokenizer {
  /// The maximum number of tokenized code blocks kept in the cache.
  private static let cacheLimit = 128

  private static let tokenizer = PrismTokenizer()
  private static var cache: [CacheKey: [CodeToken]] = [:]
  private static var insertionOrder: [CacheKey] = []

  /// Tokenizes `code`, reusing a previous result when one is available.
  ///
  /// Returns a single plain token when there is no language hint or no tokenizer.
  static func tokenize(code: String, language: String?) -> [CodeToken] {
    guard let tokenizer, let language else {
      return [CodeToken(content: code, type: .plain)]
    }

    let key = CacheKey(code: code, language: language)

    if let tokens = cache[key] {
      return tokens
    }

    let tokens = tokenizer.tokenize(code: code, language: language)

    if insertionOrder.count == cacheLimit {
      cache.removeValue(forKey: insertionOrder.removeFirst())
    }

    cache[key] = tokens
    insertionOrder.append(key)

    return tokens
  }

  private struct CacheKey: Hashable {
    let code: String
    let language: String
  }
}
