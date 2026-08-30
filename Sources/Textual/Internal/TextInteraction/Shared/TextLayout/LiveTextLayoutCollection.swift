#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  final class LiveTextLayoutCollection: TextLayoutCollection {
    var layouts: [any TextLayout] {
      if let materializedLayouts {
        return materializedLayouts
      }
      let layouts = makeLayouts()
      materializedLayouts = layouts
      return layouts
    }

    // The text-fragment layouts without their origins. Materializing lines, runs and slices is
    // expensive, so equality of this identity decides whether a published collection carries new
    // text layouts or just new origins for the ones already materialized.
    private lazy var layoutIdentity: [Text.Layout] = anchoredTextFragments.map(\.layout)

    private var materializedLayouts: [any TextLayout]?
    private var base: Text.LayoutKey.Value
    private var geometry: GeometryProxy

    init(base: Text.LayoutKey.Value, geometry: GeometryProxy) {
      self.base = base
      self.geometry = geometry
    }

    func isEqual(to other: any TextLayoutCollection) -> Bool {
      base == (other as? LiveTextLayoutCollection)?.base
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      // Same layouts with different origins do not need position reconciliation
      layoutIdentity != (other as? LiveTextLayoutCollection)?.layoutIdentity
    }

    func adoptOrigins(from other: any TextLayoutCollection) {
      // Expects `other` to carry the same layouts; only their origins are taken over
      guard let other = other as? LiveTextLayoutCollection else {
        return
      }

      base = other.base
      geometry = other.geometry

      guard let materializedLayouts else {
        return
      }

      for (layout, anchoredLayout) in zip(materializedLayouts, anchoredTextFragments) {
        (layout as? LiveTextLayout)?.origin = geometry[anchoredLayout.origin]
      }
    }

    func index(of layout: Text.Layout) -> Int? {
      indexByLayout[LayoutHashKey(layout)]
    }

    // Every fragment's selection background asks for its layout index whenever the selection
    // changes, so a linear search here is quadratic per selection change over the document
    private lazy var indexByLayout: [LayoutHashKey: Int] = {
      var indexByLayout = [LayoutHashKey: Int](minimumCapacity: layoutIdentity.count)
      for (index, layout) in layoutIdentity.enumerated() {
        // Keep the first index for equal layouts, matching a first-match linear search
        if indexByLayout[LayoutHashKey(layout)] == nil {
          indexByLayout[LayoutHashKey(layout)] = index
        }
      }
      return indexByLayout
    }()

    private var anchoredTextFragments: [Text.LayoutKey.AnchoredLayout] {
      // We are only interested in text fragments
      base.filter(\.layout.isTextFragment)
    }

    private func makeLayouts() -> [any TextLayout] {
      anchoredTextFragments.map { anchoredLayout in
        LiveTextLayout(
          anchoredLayout: anchoredLayout,
          geometry: geometry
        )
      }
    }
  }

  /// Wraps `Text.Layout` — which is `Equatable` but not `Hashable` — for use as a dictionary
  /// key. The hash combines values derived from the lines, so equal layouts hash equally and
  /// collisions fall back to the equality check.
  private struct LayoutHashKey: Hashable {
    let layout: Text.Layout

    init(_ layout: Text.Layout) {
      self.layout = layout
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.layout == rhs.layout
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(layout.count)
      guard let firstLine = layout.first else {
        return
      }
      let rect = firstLine.typographicBounds.rect
      hasher.combine(rect.origin.x)
      hasher.combine(rect.origin.y)
      hasher.combine(rect.size.width)
      hasher.combine(rect.size.height)
    }
  }

  final class LiveTextLayout: TextLayout {
    var attributedString: NSAttributedString {
      joinedAttributedString.joined
    }

    var origin: CGPoint

    private(set) lazy var bounds: CGRect = makeBounds()
    private(set) lazy var lines: [any TextLine] = makeLines()

    let base: Text.Layout

    private lazy var contents = base.materializeContents()
    private lazy var joinedAttributedString = contents.attributedStrings.joined()

    convenience init(
      anchoredLayout: Text.LayoutKey.AnchoredLayout,
      geometry: GeometryProxy
    ) {
      self.init(
        base: anchoredLayout.layout,
        origin: geometry[anchoredLayout.origin]
      )
    }

    init(base: Text.Layout, origin: CGPoint) {
      self.base = base
      self.origin = origin
    }

    private func makeBounds() -> CGRect {
      base.map(\.typographicBounds.rect)
        .reduce(CGRect.null, CGRectUnion)
    }

    private func makeLines() -> [any TextLine] {
      guard contents.attributedStrings.count > 1 else {
        return base.map {
          LiveTextLine(base: $0)
        }
      }

      // Get the offset mappings on the layout strings to maintain object identity
      let (_, characterOffsets) = contents.layoutAttributedStrings.joined()

      return zip(base, contents.lineFragments).compactMap { line, lineFragment in
        guard let offset = characterOffsets[.init(lineFragment.attributedString)] else {
          return nil
        }

        return LiveTextLine(base: line, offset: offset)
      }
    }
  }

  final class LiveTextLine: TextLine {
    var origin: CGPoint {
      base.origin
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    private(set) lazy var runs: [any TextRun] = makeRuns()

    let base: Text.Layout.Line
    let offset: Int

    init(base: Text.Layout.Line, offset: Int = 0) {
      self.base = base
      self.offset = offset
    }

    private func makeRuns() -> [any TextRun] {
      if base.isEmpty {
        // Return a newline run for empty lines
        return [
          EmptyRun(
            typographicBounds: base.typographicBounds.rect,
            slice: .init(
              typographicBounds: base.typographicBounds.rect,
              characterRange: offset..<(offset + 1)
            )
          )
        ]
      } else {
        return base.map { run in
          LiveTextRun(base: run, offset: offset)
        }
      }
    }
  }

  final class LiveTextRun: TextRun {
    var layoutDirection: LayoutDirection {
      base.layoutDirection
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    var url: URL? {
      base.url
    }

    private(set) lazy var slices: [any TextRunSlice] = makeRunSlices()

    let base: Text.Layout.Run
    let offset: Int

    init(base: Text.Layout.Run, offset: Int) {
      self.base = base
      self.offset = offset
    }

    private func makeRunSlices() -> [any TextRunSlice] {
      zip(base, base.characterRanges).map { slice, characterRange in
        LiveTextRunSlice(
          base: slice,
          characterRange: characterRange.offset(by: offset)
        )
      }
    }
  }

  struct EmptyRun: TextRun {
    let layoutDirection: LayoutDirection = .localeBased()
    let typographicBounds: CGRect
    let url: URL? = nil
    let slice: EmptyRunSlice

    var slices: [any TextRunSlice] {
      [slice]
    }
  }

  final class LiveTextRunSlice: TextRunSlice {
    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    let characterRange: Range<Int>
    let base: Text.Layout.RunSlice

    init(base: Text.Layout.RunSlice, characterRange: Range<Int>) {
      self.base = base
      self.characterRange = characterRange
    }
  }

  struct EmptyRunSlice: TextRunSlice {
    let typographicBounds: CGRect
    let characterRange: Range<Int>
  }
#endif
