import SwiftUI

// MARK: - Overview
//
// Effects reach the renderer the same way attachments and links do: the effect is stored in
// attributed content as a `Textual.TextRunEffect` attribute, TextBuilder copies it onto the
// `Text` for that run as a `TextAttribute`, and TextRunEffectRenderer reads it back off the
// laid-out run.

struct TextRunEffectAttribute: TextAttribute {
  var effect: AnyTextRunEffect

  init(_ effect: AnyTextRunEffect) {
    self.effect = effect
  }
}

extension Text.Layout.Run {
  var textRunEffect: AnyTextRunEffect? {
    self[TextRunEffectAttribute.self]?.effect
  }
}
