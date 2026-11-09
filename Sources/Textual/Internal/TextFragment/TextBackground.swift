import SwiftUI

// MARK: - Overview
//
// SwiftUI draws a run's `backgroundColor` attribute as part of the `Text` itself, so the color
// sits above anything in the fragment's background. On macOS the selection highlight is painted
// in that background, which lets an inline code background cover the selection.
//
// When the selection is painted behind the text, TextBuilder lifts the background color off the
// attributed string and carries it as a `TextBackgroundAttribute` instead. `TextBackgroundView`
// then paints those colors from the resolved `Text.Layout`, below the selection highlight, giving
// the order background, selection, text that block-level backgrounds already have.
//
// The rectangles follow SwiftUI's own drawing, so lifting a background does not move it:
// horizontally a background spans its run, with both edges snapped down to the pixel grid, and
// vertically it spans the tallest ascent and descent of any run on the line, so a smaller font
// (such as inline code) is still covered to the height of the surrounding text.

struct TextBackgroundAttribute: TextAttribute {
  var color: Color

  init(_ color: Color) {
    self.color = color
  }
}

extension Text.Layout.Run {
  var textBackgroundColor: Color? {
    self[TextBackgroundAttribute.self]?.color
  }
}

struct TextBackgroundView: View {
  @Environment(\.displayScale) private var displayScale

  private let layout: Text.Layout
  private let origin: CGPoint

  init(layout: Text.Layout, origin: CGPoint) {
    self.layout = layout
    self.origin = origin
  }

  var body: some View {
    let backgroundRects = layout.backgroundRects(displayScale: displayScale)

    Canvas { context, _ in
      context.translateBy(x: origin.x, y: origin.y)
      for (rect, color) in backgroundRects {
        context.fill(Path(rect), with: .color(color))
      }
    }
  }
}

extension Text.Layout {
  /// The background rectangles of the runs that carry a `TextBackgroundAttribute`.
  ///
  /// Adjacent runs on a line with the same color are merged, so a background split across runs
  /// (for example, by font fallback) is filled once instead of showing seams where they meet.
  func backgroundRects(displayScale: CGFloat) -> [(rect: CGRect, color: Color)] {
    let scale = Swift.max(displayScale, 1)
    var result: [(rect: CGRect, color: Color)] = []

    for line in self {
      // Every run on a line shares its baseline, so the tallest ascent and descent bound them all.
      // The line's own bounds are rounded and would overshoot.
      var ascent: CGFloat = 0
      var descent: CGFloat = 0
      var hasBackground = false

      for run in line {
        ascent = Swift.max(ascent, run.typographicBounds.ascent)
        descent = Swift.max(descent, run.typographicBounds.descent)
        hasBackground = hasBackground || run.textBackgroundColor != nil
      }

      guard hasBackground else { continue }

      let baseline = line.typographicBounds.origin.y
      var pending: (rect: CGRect, color: Color)?

      for run in line {
        guard let color = run.textBackgroundColor else {
          if let current = pending {
            result.append(current)
            pending = nil
          }
          continue
        }

        let runBounds = run.typographicBounds.rect
        let minX = (runBounds.minX * scale).rounded(.down) / scale
        let maxX = (runBounds.maxX * scale).rounded(.down) / scale
        let rect = CGRect(
          x: minX,
          y: baseline - ascent,
          width: maxX - minX,
          height: ascent + descent
        )

        if let current = pending, current.color == color,
          current.rect.maxX == rect.minX || rect.maxX == current.rect.minX
        {
          pending = (current.rect.union(rect), color)
        } else {
          if let current = pending {
            result.append(current)
          }
          pending = (rect, color)
        }
      }

      if let current = pending {
        result.append(current)
      }
    }

    return result
  }
}
