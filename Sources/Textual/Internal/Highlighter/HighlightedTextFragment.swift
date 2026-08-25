import SwiftUI

// MARK: - Overview
//
// HighlightedTextFragment displays syntax-highlighted code. Tokenization is the expensive
// step and its timing depends on the current SyntaxHighlightingMode:
//
// - .asynchronous (default) tokenizes in a task keyed by content, and highlights on token
//   or environment changes (theme, color scheme, dynamic type).
// - .synchronous tokenizes and highlights while the body is evaluated, so that offscreen
//   renderers draw highlighted code on their very first pass.
//
// Highlighting itself — turning tokens into an AttributedString — is a pure function in
// both modes.
//
// The presentationIntent is preserved after highlighting so pasteboard formatters can
// reconstruct the block structure when copying code.

struct HighlightedTextFragment: View {
  @Environment(\.textEnvironment) private var textEnvironment
  @Environment(\.syntaxHighlightingMode) private var syntaxHighlightingMode

  @State private var model = Model()

  private let content: AttributedSubstring
  private let languageHint: String?
  private let theme: StructuredText.HighlighterTheme

  init(
    _ content: AttributedSubstring,
    languageHint: String?,
    theme: StructuredText.HighlighterTheme
  ) {
    self.content = content
    self.languageHint = languageHint
    self.theme = theme
  }

  var body: some View {
    TextFragment(highlightedCode)
      .foregroundStyle(theme.foregroundColor)
      // Keyed by the mode as well as the content, so that a fragment switched over to
      // asynchronous highlighting still tokenizes
      .task(id: Tuple(content, syntaxHighlightingMode)) {
        guard syntaxHighlightingMode == .asynchronous else { return }
        await model.tokenize(
          content: content,
          languageHint: languageHint
        )
      }
      .onChange(of: Tuple(model.tokens, textEnvironment)) { _, newValue in
        model.highlight(
          tokens: newValue.values.0,
          presentationIntent: content.presentationIntent,
          using: theme,
          environment: newValue.values.1
        )
      }
  }

  private var highlightedCode: AttributedString {
    switch syntaxHighlightingMode {
    case .asynchronous:
      model.highlightedCode ?? AttributedString(content)
    case .synchronous:
      Model.highlightedCode(
        tokens: SynchronousCodeTokenizer.tokenize(
          code: String(content.characters[...]),
          language: languageHint
        ),
        presentationIntent: content.presentationIntent,
        using: theme,
        environment: textEnvironment
      )
    }
  }
}

extension HighlightedTextFragment {
  @MainActor @Observable final class Model {
    var tokens: [CodeToken] = []
    var highlightedCode: AttributedString?

    func tokenize(content: AttributedSubstring, languageHint: String?) async {
      let code = String(content.characters[...])
      tokens = [CodeToken(content: code, type: .plain)]

      if let tokenizer = CodeTokenizer.shared, let languageHint {
        tokens = await tokenizer.tokenize(code: code, language: languageHint)
      }
    }

    func highlight(
      tokens: [CodeToken],
      presentationIntent: PresentationIntent?,
      using theme: StructuredText.HighlighterTheme,
      environment: TextEnvironmentValues
    ) {
      self.highlightedCode = Self.highlightedCode(
        tokens: tokens,
        presentationIntent: presentationIntent,
        using: theme,
        environment: environment
      )
    }

    static func highlightedCode(
      tokens: [CodeToken],
      presentationIntent: PresentationIntent?,
      using theme: StructuredText.HighlighterTheme,
      environment: TextEnvironmentValues
    ) -> AttributedString {
      var attributes = AttributeContainer()
      // Re-apply the presentation intent for pasteboard formatters
      attributes.presentationIntent = presentationIntent
      ForegroundColorProperty(theme.foregroundColor)
        .apply(in: &attributes, environment: environment)
      var highlightedCode = AttributedString()

      for token in tokens {
        var content = AttributedString(token.content)
        var tokenAttributes = attributes

        if let tokenProperties = theme.tokenProperties[token.type] {
          tokenProperties.apply(in: &tokenAttributes, environment: environment)
        }

        content.mergeAttributes(tokenAttributes)
        highlightedCode.append(content)
      }

      return highlightedCode
    }
  }
}
