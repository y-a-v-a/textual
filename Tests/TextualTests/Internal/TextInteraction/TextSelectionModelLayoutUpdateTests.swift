#if TEXTUAL_ENABLE_TEXT_SELECTION && !targetEnvironment(macCatalyst)
  import Foundation
  import SwiftUI
  import Testing

  @testable import Textual

  struct TextSelectionModelLayoutUpdateTests {
    @Test func originOnlyChangeAdoptsOriginsAndKeepsSelection() {
      // given
      let current = SpyTextLayoutCollection(identity: 1, origins: 1)
      let model = TextSelectionModel(layoutCollection: current)
      let range = TextRange(start: position, end: position)
      model.selectedRange = range

      // when
      model.setLayoutCollection(SpyTextLayoutCollection(identity: 1, origins: 2))

      // then
      #expect(current.adoptedOrigins == 2)
      #expect(model.selectedRange == range)
    }

    @Test func layoutChangeReplacesTheCollection() {
      // given
      let current = SpyTextLayoutCollection(identity: 1, origins: 1)
      let replacement = SpyTextLayoutCollection(identity: 2, origins: 1)
      let model = TextSelectionModel(layoutCollection: current)

      // when
      model.setLayoutCollection(replacement)
      // An origin-only successor of the replacement adopts into it, proving the model
      // replaced the original collection rather than keeping it
      model.setLayoutCollection(SpyTextLayoutCollection(identity: 2, origins: 2))

      // then
      #expect(current.adoptedOrigins == nil)
      #expect(replacement.adoptedOrigins == 2)
    }

    @Test func identicalCollectionIsIgnored() {
      // given
      let current = SpyTextLayoutCollection(identity: 1, origins: 1)
      let model = TextSelectionModel(layoutCollection: current)
      let range = TextRange(start: position, end: position)
      model.selectedRange = range

      // when
      model.setLayoutCollection(SpyTextLayoutCollection(identity: 1, origins: 1))

      // then
      #expect(current.adoptedOrigins == nil)
      #expect(model.selectedRange == range)
    }

    // MARK: - Helpers

    private var position: TextPosition {
      TextPosition(
        indexPath: .init(runSlice: 0, run: 0, line: 0, layout: 0),
        affinity: .downstream
      )
    }
  }

  private final class SpyTextLayoutCollection: TextLayoutCollection {
    var layouts: [any TextLayout] {
      []
    }

    let identity: Int
    private(set) var origins: Int
    private(set) var adoptedOrigins: Int?

    init(identity: Int, origins: Int) {
      self.identity = identity
      self.origins = origins
    }

    func isEqual(to other: any TextLayoutCollection) -> Bool {
      guard let other = other as? SpyTextLayoutCollection else {
        return false
      }
      return identity == other.identity && origins == other.origins
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      identity != (other as? SpyTextLayoutCollection)?.identity
    }

    func adoptOrigins(from other: any TextLayoutCollection) {
      guard let other = other as? SpyTextLayoutCollection else {
        return
      }
      origins = other.origins
      adoptedOrigins = other.origins
    }

    func index(of layout: Text.Layout) -> Int? {
      nil
    }
  }
#endif
