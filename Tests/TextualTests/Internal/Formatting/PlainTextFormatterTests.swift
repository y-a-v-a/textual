import Foundation
import SwiftUI
import Testing

@testable import Textual

struct PlainTextFormatterTests {
  @Test func simpleParagraph() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(markdown: "This is a simple paragraph.")
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "This is a simple paragraph.")
  }

  @Test func multipleParagraphs() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          First paragraph.

          Second paragraph.

          Third paragraph.
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.")
  }

  @Test func headings() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          # Heading 1

          ## Heading 2

          ### Heading 3
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "Heading 1\n\nHeading 2\n\nHeading 3")
  }

  @Test func unorderedList() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          * First item
          * Second item
          * Third item
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "  • First item\n  • Second item\n  • Third item")
  }

  @Test func orderedList() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          1. First item
          2. Second item
          3. Third item
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "  1. First item\n  2. Second item\n  3. Third item")
  }

  @Test func nestedUnorderedList() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          - First item
            - Nested item 1
            - Nested item 2
          - Second item
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(
      result
        == "  • First item\n    • Nested item 1\n    • Nested item 2\n  • Second item"
    )
  }

  @Test func nestedOrderedList() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          1. First item
             1. Nested item 1
             2. Nested item 2
          2. Second item
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(
      result
        == "  1. First item\n    1. Nested item 1\n    2. Nested item 2\n  2. Second item"
    )
  }

  @Test func mixedNestedList() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          1. Ordered first
             - Unordered nested
             - Another unordered
          2. Ordered second
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(
      result
        == "  1. Ordered first\n    • Unordered nested\n    • Another unordered\n  2. Ordered second"
    )
  }

  @Test func simpleBlockQuote() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          > This is a quote.
          >
          > It has two paragraphs.
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "  This is a quote.\n\n  It has two paragraphs.")
  }

  @Test func blockQuoteWithParagraphs() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          Before quote.

          > This is a quote.

          After quote.
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "Before quote.\n\n  This is a quote.\n\nAfter quote.")
  }

  // MARK: - Code Blocks

  @Test func codeBlock() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          ```swift
          func hello() {
              print("Hello")
          }
          ```
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "func hello() {\n    print(\"Hello\")\n}\n")
  }

  @Test func codeBlockWithSurroundingText() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          Before code.

          ```
          code line 1
          code line 2
          ```

          After code.
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "Before code.\n\ncode line 1\ncode line 2\n\n\nAfter code.")
  }

  @Test func simpleTable() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          | Header 1 | Header 2 |
          | --- | --- |
          | Cell A1 | Cell A2 |
          | Cell B1 | Cell B2 |
          """
      )
    )
    let expected = """
      Header 1,Header 2
      Cell A1,Cell A2
      Cell B1,Cell B2
      """

    // when
    let result = formatter.plainText()

    // then
    #expect(result == expected)
  }

  @Test func complexMixedContent() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          # Main Title

          Introduction paragraph.

          ## Section 1

          - First point
          - Second point
            - Nested point

          ## Section 2

          Some text before table.

          | Column A | Column B |
          | --- | --- |
          | Value 1 | Value 2 |

          ## Conclusion

          Final paragraph.
          """
      )
    )
    let expected = """
      Main Title

      Introduction paragraph.

      Section 1

        • First point
        • Second point
          • Nested point

      Section 2

      Some text before table.

      Column A,Column B
      Value 1,Value 2

      Conclusion

      Final paragraph.
      """

    // when
    let result = formatter.plainText()

    // then
    #expect(result == expected)
  }

  @Test func listAfterParagraph() throws {
    // given
    let formatter = try Formatter(
      NSAttributedString(
        markdown: """
          Here is a paragraph.

          - Item 1
          - Item 2
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "Here is a paragraph.\n\n  • Item 1\n  • Item 2")
  }

  @Test func emptyString() throws {
    // given
    let formatter = Formatter(NSAttributedString())

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "")
  }

  // MARK: - Partial selections

  @Test func textInsideUnorderedListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "cond it",
      in: """
        * First item
        * Second item
        * Third item
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "cond it")
  }

  @Test func textInsideOrderedListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "cond it",
      in: """
        1. First item
        2. Second item
        3. Third item
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "cond it")
  }

  @Test func firstWordOfListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "Second",
      in: """
        1. First item
        2. Second item
        """
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "Second")
  }

  @Test func textInsideNestedListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "sted item",
      in: """
        - First item
          - Nested item 1
        - Second item
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "sted item")
  }

  @Test func textInsideBlockQuote() throws {
    // given
    let formatter = try Formatter(
      selecting: "is a",
      in: """
        > This is a quote.
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "is a")
  }

  @Test func textInsideTableCell() throws {
    // given
    let formatter = try Formatter(
      selecting: "one, two",
      in: """
        | Key | Value |
        | --- | --- |
        | Tags | one, two |
        """
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "one, two")
  }

  @Test func textInsideCodeBlockInListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "let x = 1",
      in: """
        - Item

          ```
          let x = 1
          ```
        """
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "let x = 1")
  }

  @Test func selectionStartingInsideUnorderedListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "cond itemThird item",
      in: """
        * First item
        * Second item
        * Third item
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "cond item\n  • Third item")
  }

  @Test func selectionStartingInsideOrderedListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "cond itemThird it",
      in: """
        1. First item
        2. Second item
        3. Third item
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "cond item\n  3. Third it")
  }

  @Test func selectionStartingInsideNestedListItem() throws {
    // given
    let formatter = try Formatter(
      selecting: "sted item 1Nested item 2Second item",
      in: """
        - First item
          - Nested item 1
          - Nested item 2
        - Second item
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "sted item 1\n    • Nested item 2\n  • Second item")
  }

  @Test func selectionStartingAtListItemStart() throws {
    // given
    let formatter = try Formatter(
      selecting: "Second itemThird item",
      in: """
        1. First item
        2. Second item
        3. Third item
        """
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "  2. Second item\n  3. Third item")
  }

  @Test func selectionStartingInsideBlockQuote() throws {
    // given
    let formatter = try Formatter(
      selecting: "quote.Second paragraph.",
      in: """
        > This is a quote.
        >
        > Second paragraph.
        """,
      startsInsideBlock: true
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "quote.\n\n  Second paragraph.")
  }
}
