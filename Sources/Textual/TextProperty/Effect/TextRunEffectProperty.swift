import SwiftUI

/// Attaches a custom drawing effect to a span of text.
///
/// See ``TextRunEffect`` for what an effect can draw and when it draws.
public struct TextRunEffectProperty: TextProperty {
  private let effect: AnyTextRunEffect

  /// Creates a property that attaches an effect to the spans it styles.
  ///
  /// - Parameters:
  ///   - effect: The effect to attach.
  ///   - placement: Where the effect draws. The default is ``TextRunEffectPlacement/behind``.
  public init(_ effect: some TextRunEffect, placement: TextRunEffectPlacement = .behind) {
    self.effect = AnyTextRunEffect(effect, placement: placement)
  }

  public func apply(in attributes: inout AttributeContainer, environment: TextEnvironmentValues) {
    attributes.textual.textRunEffect = effect
  }
}

extension TextProperty where Self == TextRunEffectProperty {
  /// Attaches a custom drawing effect to a span of text.
  ///
  /// ```swift
  /// InlineText(markdown: "This is **highlighted** text")
  ///   .textual.inlineStyle(
  ///     InlineStyle().strong(.textRunEffect(SearchMatchEffect(color: .yellow)))
  ///   )
  /// ```
  ///
  /// - Parameters:
  ///   - effect: The effect to attach.
  ///   - placement: Where the effect draws. The default is ``TextRunEffectPlacement/behind``.
  public static func textRunEffect(
    _ effect: some TextRunEffect,
    placement: TextRunEffectPlacement = .behind
  ) -> Self {
    TextRunEffectProperty(effect, placement: placement)
  }
}
