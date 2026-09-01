import SwiftUI

extension StructuredText {
  struct BlockContent<Content: AttributedStringProtocol>: View {
    // Deriving the block decomposition walks every run; memoizing it keeps that cost tied to
    // content changes instead of body evaluations. The memo hits on content equality even when
    // the backing string changed (a streamed re-parse), so it must cache self-contained slices,
    // never indices into `content`
    @State private var blockSlices =
      Memo<Tuple<Content, PresentationIntent.IntentType?>, [AttributedString.BlockSlice]>()

    private let parent: PresentationIntent.IntentType?
    private let content: Content

    init(parent: PresentationIntent.IntentType? = nil, content: Content) {
      self.parent = parent
      self.content = content
    }

    var body: some View {
      let slices = blockSlices(Tuple(content, parent)) {
        content.blockSlices(parent: parent)
      }

      BlockVStack {
        ForEach(slices.indices, id: \.self) { index in
          let slice = slices[index]
          Block(intent: slice.intent, content: slice.content)
        }
      }
    }
  }
}

extension StructuredText {
  struct Block: View {
    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring

    init(intent: PresentationIntent.IntentType?, content: AttributedSubstring) {
      self.intent = intent
      self.content = content
    }

    var body: some View {
      switch intent?.kind {
      case .paragraph where content.isMathBlock:
        MathBlock(content)
      case .paragraph:
        Paragraph(content)
      case .header(let level):
        Heading(content, level: level)
      case .orderedList:
        OrderedList(intent: intent, content: content)
      case .unorderedList:
        UnorderedList(intent: intent, content: content)
      case .codeBlock(let languageHint) where languageHint?.lowercased() == "math":
        MathCodeBlock(content)
      case .codeBlock(let languageHint):
        CodeBlock(content, languageHint: languageHint)
      case .blockQuote:
        BlockQuote(intent: intent, content: content)
      case .thematicBreak:
        ThematicBreak(content)
      case .table(let columns):
        Table(intent: intent, content: content, columns: columns)
      default:
        Paragraph(content)
      }
    }
  }
}
