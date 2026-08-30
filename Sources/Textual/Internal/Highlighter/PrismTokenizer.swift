import Foundation
import os

#if canImport(JavaScriptCore)
  import JavaScriptCore
#endif

// MARK: - Overview
//
// PrismTokenizer is the synchronous core of Textual's syntax highlighting. It owns a
// JavaScriptCore context with the bundled Prism.js and turns code into tokens.
//
// The type is not thread-safe on its own: a JSContext must not be used concurrently.
// Callers pick an isolation domain and keep one instance in it. CodeTokenizer owns an
// instance for background tokenization, and SynchronousCodeTokenizer owns a main-actor
// instance for offscreen rendering.
//
// The tokenizer gracefully degrades when JavaScriptCore is unavailable, when the Prism
// bundle is missing, or when tokenization fails. In all cases, callers end up with a
// single plain token containing the entire code string.

struct CodeToken: Hashable, Sendable {
  let content: String
  let type: StructuredText.HighlighterTheme.TokenType
}

#if canImport(JavaScriptCore)
  final class PrismTokenizer {
    private let context: JSContext
    private let logger = Logger(category: .codeTokenizer)

    init?() {
      guard let context = JSContext() else {
        logger.error("JavascriptCore is not available.")
        return nil
      }

      guard
        let bundleURL = Bundle.textual?.url(
          forResource: "prism-bundle",
          withExtension: "js"
        ),
        let script = try? String(contentsOf: bundleURL, encoding: .utf8)
      else {
        logger.error("Prism JavaScript bundle is missing.")
        return nil
      }

      context.evaluateScript(script)
      self.context = context
    }

    func tokenize(code: String, language: String) -> [CodeToken] {
      guard
        let tokenizeCode = context.objectForKeyedSubscript("tokenizeCode"),
        let result = tokenizeCode.call(withArguments: [code, language]),
        let array = result.toArray() as? [[String: String]]
      else {
        logger.error("Tokenization failed.")
        return [CodeToken(content: code, type: .plain)]
      }

      return array.compactMap { token in
        guard
          let content = token["content"],
          let type = token["type"]
        else {
          return nil
        }
        return CodeToken(content: content, type: .init(rawValue: type))
      }
    }
  }
#else
  final class PrismTokenizer {
    private let logger = Logger(category: .codeTokenizer)

    init?() {
      logger.error("JavascriptCore is not available in this platform.")
      return nil
    }

    func tokenize(code: String, language: String) -> [CodeToken] {
      [CodeToken(content: code, type: .plain)]
    }
  }
#endif

extension Logger.Textual.Category {
  static let codeTokenizer = Self(rawValue: "codeTokenizer")
}
