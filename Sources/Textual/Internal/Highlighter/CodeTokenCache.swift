import ConcurrencyExtras
import Foundation

// MARK: - Overview
//
// Tokens are a pure function of the code and its language, so tokenization results are
// memoized in a single bounded cache shared by both tokenizers. Asynchronous tokenization
// then happens once per code block instead of once per view identity — scrolling a block
// back in or streaming an unrelated edit reuses the previous result — and code already
// tokenized in one mode is free in the other.

final class CodeTokenCache: Sendable {
  static let shared = CodeTokenCache()

  private let limit: Int
  private let storage: LockIsolated<Storage>

  /// Creates a cache that keeps at most `limit` tokenized code blocks.
  init(limit: Int = 128) {
    self.limit = limit
    self.storage = LockIsolated(Storage())
  }

  func tokens(code: String, language: String) -> [CodeToken]? {
    let key = Key(code: code, language: language)
    return storage.withValue { storage in
      storage.entries[key]
    }
  }

  func store(_ tokens: [CodeToken], code: String, language: String) {
    let key = Key(code: code, language: language)
    let limit = self.limit

    storage.withValue { storage in
      guard storage.entries[key] == nil else {
        return
      }

      if storage.insertionOrder.count == limit {
        storage.entries.removeValue(forKey: storage.insertionOrder.removeFirst())
      }

      storage.entries[key] = tokens
      storage.insertionOrder.append(key)
    }
  }

  private struct Key: Hashable {
    let code: String
    let language: String
  }

  private struct Storage {
    var entries: [Key: [CodeToken]] = [:]
    var insertionOrder: [Key] = []
  }
}
