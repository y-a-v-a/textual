// Mac Catalyst is excluded because `UIWindow` cannot be created in the test host.
#if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
  import CoreGraphics
  import SwiftUI
  import Testing

  import Textual

  @MainActor
  struct TextRunEffectTests {
    /// Fills a run with an opaque color, so that whether the glyphs survive says which of the
    /// two drew last.
    private struct FillEffect: TextRunEffect {
      var color: Color

      func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
        context.fill(Path(run.typographicBounds.rect), with: .color(color))
      }
    }

    /// Clips to the left half of the run, to check that context state stays local to an effect.
    private struct ClippingFillEffect: TextRunEffect {
      var color: Color

      func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
        let bounds = run.typographicBounds.rect
        context.clip(to: Path(bounds.divided(atDistance: bounds.width / 2, from: .minXEdge).slice))
        context.fill(Path(bounds), with: .color(color))
      }
    }

    private func render(_ placement: TextRunEffectPlacement?) -> CGImage? {
      let text = InlineText(markdown: "**Highlighted**")
        .font(.system(size: 40))
        .foregroundStyle(.black)

      guard let placement else {
        return OffscreenHost.firstFrame(of: text)
      }

      return OffscreenHost.firstFrame(
        of: text.textual.inlineStyle(
          InlineStyle().strong(
            .bold,
            .textRunEffect(FillEffect(color: .red), placement: placement)
          )
        )
      )
    }

    private func redPixelCount(_ image: CGImage) -> Int {
      image.countPixels { $0.red > 0.5 && $0.green < 0.4 && $0.blue < 0.4 }
    }

    private func glyphPixelCount(_ image: CGImage) -> Int {
      image.countPixels { $0.red < 0.25 && $0.green < 0.25 && $0.blue < 0.25 }
    }

    @Test func effectsBehindTheTextDrawUnderTheGlyphs() throws {
      let image = try #require(render(.behind))

      #expect(redPixelCount(image) > 0)
      // The glyphs are drawn after the fill, so they survive it
      #expect(glyphPixelCount(image) > 0)
    }

    @Test func effectsInFrontOfTheTextDrawOverTheGlyphs() throws {
      let image = try #require(render(.inFront))

      #expect(redPixelCount(image) > 0)
      // The opaque fill is drawn after the glyphs, so it covers them
      #expect(glyphPixelCount(image) == 0)
    }

    @Test func textWithoutEffectsIsUnchanged() throws {
      let plain = try #require(render(nil))

      #expect(redPixelCount(plain) == 0)
      #expect(glyphPixelCount(plain) > 0)
    }

    @Test func effectsDoNotLeakGraphicsContextState() throws {
      let image = try #require(
        OffscreenHost.firstFrame(
          of: InlineText(markdown: "**Highlighted**")
            .font(.system(size: 40))
            .foregroundStyle(.black)
            .textual.inlineStyle(
              InlineStyle().strong(
                .bold,
                .textRunEffect(ClippingFillEffect(color: .red))
              )
            )
        )
      )

      let unclipped = try #require(render(.behind))

      // The effect clipped itself to half the run, so it fills less of it
      #expect(redPixelCount(image) > 0)
      #expect(redPixelCount(image) < redPixelCount(unclipped))

      // The text is drawn in full regardless. Were the clip to leak, roughly half the glyph
      // coverage would disappear with it; the remaining difference is antialiasing against red
      // rather than white.
      #expect(glyphPixelCount(image) > glyphPixelCount(unclipped) * 9 / 10)
    }
  }
#endif
