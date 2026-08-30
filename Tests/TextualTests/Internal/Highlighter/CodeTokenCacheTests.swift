import Foundation
import Testing

@testable import Textual

struct CodeTokenCacheTests {
  @Test func storedTokensAreReturned() {
    let cache = CodeTokenCache()
    let tokens = [CodeToken(content: "let x = 1", type: .init(rawValue: "keyword"))]

    cache.store(tokens, code: "let x = 1", language: "swift")

    #expect(cache.tokens(code: "let x = 1", language: "swift") == tokens)
  }

  @Test func lookupMissesOnDifferentCodeOrLanguage() {
    let cache = CodeTokenCache()
    let tokens = [CodeToken(content: "let x = 1", type: .plain)]

    cache.store(tokens, code: "let x = 1", language: "swift")

    #expect(cache.tokens(code: "let x = 2", language: "swift") == nil)
    #expect(cache.tokens(code: "let x = 1", language: "kotlin") == nil)
  }

  @Test func oldestEntryIsEvictedBeyondTheLimit() {
    let cache = CodeTokenCache(limit: 2)

    cache.store([CodeToken(content: "a", type: .plain)], code: "a", language: "swift")
    cache.store([CodeToken(content: "b", type: .plain)], code: "b", language: "swift")
    cache.store([CodeToken(content: "c", type: .plain)], code: "c", language: "swift")

    #expect(cache.tokens(code: "a", language: "swift") == nil)
    #expect(cache.tokens(code: "b", language: "swift") != nil)
    #expect(cache.tokens(code: "c", language: "swift") != nil)
  }

  @Test func storingTwiceKeepsTheFirstResultAndEvictionOrder() {
    let cache = CodeTokenCache(limit: 2)
    let first = [CodeToken(content: "a", type: .plain)]

    cache.store(first, code: "a", language: "swift")
    cache.store([CodeToken(content: "a", type: .init(rawValue: "keyword"))], code: "a", language: "swift")
    cache.store([CodeToken(content: "b", type: .plain)], code: "b", language: "swift")

    #expect(cache.tokens(code: "a", language: "swift") == first)
    #expect(cache.tokens(code: "b", language: "swift") != nil)
  }
}
