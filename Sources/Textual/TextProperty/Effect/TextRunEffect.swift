import SwiftUI

/// Where a ``TextRunEffect`` draws, relative to the text it decorates.
public enum TextRunEffectPlacement: Hashable, Sendable, CaseIterable {
  /// Draws underneath the glyphs, like a highlight.
  case behind
  /// Draws on top of the glyphs, like an overlay.
  case inFront
}

/// A custom drawing effect for a run of text.
///
/// Conform to `TextRunEffect` when a visual treatment needs more than the standard text
/// attributes can express — a highlight behind a search match, a hand-drawn underline, a
/// gradient wash. An effect draws into the `GraphicsContext` that renders the text.
///
/// ```swift
/// struct SearchMatchEffect: TextRunEffect {
///   var color: Color
///
///   func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
///     context.fill(
///       Path(roundedRect: run.typographicBounds.rect, cornerRadius: 3),
///       with: .color(color)
///     )
///   }
/// }
/// ```
///
/// Attach an effect to a span with ``TextProperty/textRunEffect(_:placement:)``:
///
/// ```swift
/// InlineText(markdown: "This is **highlighted** text")
///   .textual.inlineStyle(
///     InlineStyle().strong(.textRunEffect(SearchMatchEffect(color: .yellow)))
///   )
/// ```
///
/// To decorate arbitrary ranges rather than markup spans, set the effect on the attributed
/// string itself:
///
/// ```swift
/// attributedString[range].textual.textRunEffect = AnyTextRunEffect(
///   SearchMatchEffect(color: .yellow)
/// )
/// ```
///
/// ### Drawing order
///
/// Textual draws a fragment in three passes: every ``TextRunEffectPlacement/behind`` effect, then
/// all of the text, then every ``TextRunEffectPlacement/inFront`` effect. Within a pass, effects
/// draw in layout order. Each effect receives its own copy of the graphics context, so clipping,
/// transforms, and other context state do not leak into the text or into other effects.
public protocol TextRunEffect: Sendable, Hashable {
  /// Draws this effect for one run of laid-out text.
  ///
  /// - Parameters:
  ///   - run: The run of text this effect is attached to. Its `typographicBounds` describe where
  ///     the run sits in the fragment.
  ///   - context: The graphics context to draw into. It is a private copy, so any state this
  ///     method changes applies only to its own drawing.
  func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext)
}

/// A type-erased ``TextRunEffect`` paired with the place it draws.
///
/// Use `AnyTextRunEffect` to store an effect in an `AttributedString`, which is how you apply an
/// effect to a range that does not correspond to a markup span.
public struct AnyTextRunEffect: Sendable, Hashable {
  /// Where this effect draws, relative to the text.
  public let placement: TextRunEffectPlacement

  private let base: any TextRunEffect

  /// Creates a type-erased effect.
  ///
  /// - Parameters:
  ///   - base: The effect to erase.
  ///   - placement: Where the effect draws. The default is ``TextRunEffectPlacement/behind``.
  public init(_ base: some TextRunEffect, placement: TextRunEffectPlacement = .behind) {
    if let base = base as? AnyTextRunEffect {
      self.base = base.base
      self.placement = placement
    } else {
      self.base = base
      self.placement = placement
    }
  }

  func draw(_ run: Text.Layout.Run, in context: inout GraphicsContext) {
    base.draw(run, in: &context)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.placement == rhs.placement && AnyHashable(lhs.base) == AnyHashable(rhs.base)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(placement)
    hasher.combine(base)
  }
}
