import Foundation
import Testing

@testable import Textual

@MainActor
struct MathSourceTests {
  private func parse(_ markdown: String) throws -> AttributedString {
    try AttributedStringMarkdownParser(baseURL: nil, syntaxExtensions: [.math])
      .attributedString(for: markdown)
  }

  private func parsePlain(_ markdown: String) throws -> AttributedString {
    try AttributedStringMarkdownParser(baseURL: nil).attributedString(for: markdown)
  }

  private func formulas(in string: AttributedString) -> [String] {
    string.runs.compactMap { string[$0.range].textual.attachment?.description }
  }

  // MARK: - LaTeX reaches the typesetter as written

  @Test(arguments: [
    #"$\int x^2\,dx$"#,
    #"$\alpha + \beta$"#,
    #"$\{a, b\}$"#,
    #"$\left\{ x \right\}$"#,
    #"$a \\ b$"#,
    #"$100\%$"#,
    #"$a\_b$"#,
    #"$a*b*c$"#,
    #"$a * b * c$"#,
    #"$_a + b_$"#,
    #"$[a](b)$"#,
    #"$a<b>c$"#,
    #"$x &amp; y$"#,
    #"$\#\!\;\:$"#,
    #"$a\$b$"#,
    #"$$\int_{0}^{1} x^2\,dx = \frac{1}{3}$$"#,
    #"$$\{a*b*c\}$$"#,
  ])
  func keepsLatexVerbatim(_ formula: String) throws {
    #expect(formulas(in: try parse("Before \(formula) after")) == [formula])
  }

  @Test func keepsLatexVerbatimInsideBlocks() throws {
    #expect(formulas(in: try parse(#"# Title $a\,b$"#)) == [#"$a\,b$"#])
    #expect(formulas(in: try parse(#"- item $a\,b$"#)) == [#"$a\,b$"#])
    #expect(formulas(in: try parse(#"> quote $a\,b$"#)) == [#"$a\,b$"#])
    #expect(formulas(in: try parse(#"**bold $a\,b$ text**"#)) == [#"$a\,b$"#])
    #expect(formulas(in: try parse("| h |\n|---|\n| $a\\,b$ |")) == [#"$a\,b$"#])
  }

  @Test func keepsLatexVerbatimInInlineOnlyMarkdown() throws {
    let parser = AttributedStringMarkdownParser.inlineMarkdown(syntaxExtensions: [.math])
    #expect(formulas(in: try parser.attributedString(for: #"Sum $a\,b$."#)) == [#"$a\,b$"#])
  }

  @Test func countsSourceColumnsInBytes() throws {
    let parsed = try parse(#"é ü 日本語 $a\,b$ `$c\,d$` $e\,f$"#)
    #expect(formulas(in: parsed) == [#"$a\,b$"#, #"$e\,f$"#])
  }

  @Test func leavesTheTextAroundAFormulaAlone() throws {
    let parsed = try parse(#"*one* $a\,b$ **two** \* three"#)
    #expect(String(parsed.characters) == "one \u{FFFC} two * three")
  }

  // MARK: - Multi-line blocks

  @Test func joinsTheLinesOfABlock() throws {
    #expect(formulas(in: try parse("$$\na\\,b\n+ c\n$$")) == [#"$$a\,b + c$$"#])
    #expect(formulas(in: try parse("Intro\n$$a\n= b$$\nOutro")) == [#"$$a = b$$"#])
    #expect(formulas(in: try parse("$$\r\na\r\nb\r\n$$")) == [#"$$a b$$"#])
  }

  @Test func keepsAMultiLineBlockThatLooksLikeOtherMarkdown() throws {
    #expect(formulas(in: try parse("$$\na\n---\nb\n$$")) == [#"$$a --- b$$"#])
    #expect(formulas(in: try parse("$$\na\n- b\n$$")) == [#"$$a - b$$"#])
    #expect(formulas(in: try parse("$$\na\n> b\n$$")) == [#"$$a > b$$"#])
  }

  @Test func keepsLatexVerbatimOnLazyContinuationLines() throws {
    #expect(formulas(in: try parse("> one\ntwo $a\\,b$ three")) == [#"$a\,b$"#])
    #expect(formulas(in: try parse("- one\ntwo $a\\,b$ three")) == [#"$a\,b$"#])
  }

  @Test func removesContainerPrefixesFromABlock() throws {
    #expect(formulas(in: try parse("> $$\n> a\n> b\n> $$")) == [#"$$a b$$"#])
    #expect(formulas(in: try parse("> > $$\n> > a\n> > $$")) == [#"$$a$$"#])
    #expect(formulas(in: try parse("- $$\n  a\n  $$")) == [#"$$a$$"#])
  }

  @Test func doesNotJoinABlockAcrossABlankLine() throws {
    let markdown = "$$ a\n\nb $$"
    #expect(formulas(in: try parse(markdown)).isEmpty)
    #expect(formulas(in: try parse("> $$ a\n>\n> b $$")).isEmpty)
    #expect(formulas(in: try parse("One $$ dollar\n\nTwo $$x$$")) == ["$$x$$"])
  }

  // MARK: - Everything else stays as Markdown wrote it

  @Test(arguments: [
    #"Use `$a\,b$` here"#,
    "Before\n\n```\n$a\\,b$\n\n$$c\\,d$$\n```\n\nafter",
    "~~~\n$a\\,b$\n~~~",
    "Before\n\n    $a\\,b$\n\nafter",
    "> ```\n> $a\\,b$\n> ```",
    "<div>\n$a\\,b$\n</div>",
    "[link](https://example.com/$5\\,6$)",
    #"Between $ 5\,6 and 10 $ now"#,
    #"It costs $5\, and $10\, today."#,
    "It costs \\$5 and \\$10 today.",
    "> one\nlong text `$a\\,b$` z",
    "- one\nlong text `$a\\,b$` z",
    "1.  one\nlong text `$a\\,b$` z",
    "10.  one\nlong text here `$a\\,b$` z",
    "> > > one\nlong text here `$a\\,b$` z",
    "> > > > one\nlong text `$x^2$` z",
    "100000. one\nlong text `$x^2$` z",
    "100000. > > one\nlong text `$x^2$` z",
    "Nothing to see \\, here $",
  ])
  func leavesNonMathLikePlainMarkdown(_ markdown: String) throws {
    let parsed = try parse(markdown)
    #expect(formulas(in: parsed).isEmpty)
    #expect(parsed == (try parsePlain(markdown)))
  }

  @Test func doesNotEscapeInsideAnAutolink() throws {
    let markdown = "<https://example.com/$5$>"
    let parsed = try parse(markdown)
    let plain = try parsePlain(markdown)
    #expect(Set(parsed.runs.compactMap(\.link)) == Set(plain.runs.compactMap(\.link)))
  }

  @Test func findsFormulasNextToCodeThatContainsDollars() throws {
    #expect(formulas(in: try parse(#"`$a`$b\,c$"#)) == [#"$b\,c$"#])
  }

  // MARK: - Other parser features

  @Test func escapedTaskListMarkersStillDetectEscapes() throws {
    let parsed = try parse(#"- \[ ] not a task $a\[b$"#)
    #expect(formulas(in: parsed) == [#"$a\[b$"#])
    #expect(parsed.runs.allSatisfy { $0.markdownSourcePosition == nil })
    #expect(parsed.runs.contains { parsed[$0.range].textual.escapedTaskListMarker == true })
  }
}
