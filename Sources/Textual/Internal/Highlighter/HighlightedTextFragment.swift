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
      // Keyed by the content as well, so that attributes the caller changes without changing the
      // code itself, such as search highlighting, reach the screen with the current tokens
      .onChange(of: Tuple(model.tokens, textEnvironment, content)) { _, newValue in
        model.highlight(
          tokens: newValue.values.0,
          original: newValue.values.2,
          presentationIntent: newValue.values.2.presentationIntent,
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
        original: content,
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

      guard let tokenizer = CodeTokenizer.shared, let languageHint else {
        tokens = [CodeToken(content: code, type: .plain)]
        return
      }

      // A cached result can be adopted without flashing the plain placeholder first
      if let cached = CodeTokenCache.shared.tokens(code: code, language: languageHint) {
        tokens = cached
        return
      }

      tokens = [CodeToken(content: code, type: .plain)]
      let tokenized = await tokenizer.tokenize(code: code, language: languageHint)
      // The task is cancelled when the content changes, and a newer task may have already
      // published tokens for the new content (the cache path above resolves without suspending),
      // so a cancelled result must not land
      guard !Task.isCancelled else { return }
      tokens = tokenized
    }

    func highlight(
      tokens: [CodeToken],
      original: AttributedSubstring,
      presentationIntent: PresentationIntent?,
      using theme: StructuredText.HighlighterTheme,
      environment: TextEnvironmentValues
    ) {
      self.highlightedCode = Self.highlightedCode(
        tokens: tokens,
        original: original,
        presentationIntent: presentationIntent,
        using: theme,
        environment: environment
      )
    }

    static func highlightedCode(
      tokens: [CodeToken],
      original: AttributedSubstring,
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

      // Each token is sliced from the original content rather than rebuilt from its plain string,
      // so the attributes the caller's parser applied to the code survive. Theme attributes are
      // merged on top and win for the keys they set. Slicing needs the token lengths to add up to
      // the content's; when they don't (tokens left over from previous content, or a token split
      // inside a grapheme cluster), every token falls back to its own string so that no text is
      // lost or repeated.
      let slicesOriginal =
        tokens.reduce(0) { $0 + $1.content.count } == original.characters.count
      var tokenStart = original.startIndex

      for token in tokens {
        var tokenAttributes = attributes

        if let tokenProperties = theme.tokenProperties[token.type] {
          tokenProperties.apply(in: &tokenAttributes, environment: environment)
        }

        var content: AttributedString

        if slicesOriginal {
          let tokenEnd = original.characters.index(tokenStart, offsetBy: token.content.count)
          content = AttributedString(original[tokenStart..<tokenEnd])
          tokenStart = tokenEnd
        } else {
          content = AttributedString(token.content)
        }

        content.mergeAttributes(tokenAttributes)
        highlightedCode.append(content)
      }

      return highlightedCode
    }
  }
}
