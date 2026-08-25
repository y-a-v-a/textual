import SwiftUI

// MARK: - Overview
//
// TextRunEffectRenderer draws the custom effects attached to a fragment's runs.
//
// Drawing happens in three passes — behind effects, the text, then in-front effects — so that
// the order between an effect and the glyphs it decorates is part of the API rather than a
// side effect of run order. Each effect draws into its own copy of the graphics context, so
// clipping and transforms cannot leak into the text or into the next effect.
//
// The renderer is installed by TextFragment, and only on fragments whose content actually
// carries an effect. Everything else keeps SwiftUI's own text rendering path.

struct TextRunEffectRenderer: TextRenderer {
  func draw(layout: Text.Layout, in context: inout GraphicsContext) {
    draw(layout, placement: .behind, in: &context)

    for line in layout {
      context.draw(line)
    }

    draw(layout, placement: .inFront, in: &context)
  }

  private func draw(
    _ layout: Text.Layout,
    placement: TextRunEffectPlacement,
    in context: inout GraphicsContext
  ) {
    for line in layout {
      for run in line {
        guard let effect = run.textRunEffect, effect.placement == placement else {
          continue
        }

        var effectContext = context
        effect.draw(run, in: &effectContext)
      }
    }
  }
}
