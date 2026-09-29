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
          """
      )
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "  This is a quote.")
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

  // MARK: - Selections that begin inside a block

  @Test func partialFirstUnorderedItemHasNoMarker() throws {
    // given
    let formatter = try Formatter.selection(
      of: "* Answer 11219 today\n* Second item", from: "11219", to: " today")

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "11219")
  }

  @Test func partialFirstOrderedItemHasNoMarker() throws {
    // given
    let formatter = try Formatter.selection(
      of: "1. Answer 11219 today\n2. Second item", from: "11219", to: " today")

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "11219")
  }

  @Test func selectionAtItemStartKeepsMarker() throws {
    // given
    let formatter = try Formatter.selection(
      of: "* Answer 11219\n* Second item", from: "Answer", startsMidBlock: false)

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "  • Answer 11219\n  • Second item")
  }

  @Test func partialFirstItemThenWholeItems() throws {
    // given
    let formatter = try Formatter.selection(
      of: "* Answer 11219\n* Second item\n* Third item", from: "11219")

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "11219\n\n  • Second item\n  • Third item")
  }

  @Test func partialFirstOrderedItemThenWholeItemsKeepOrdinals() throws {
    // given
    let formatter = try Formatter.selection(
      of: "1. Answer 11219\n2. Second item", from: "11219")

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "11219\n\n  2. Second item")
  }

  @Test func partialNestedItemDropsEveryEnclosingMarker() throws {
    // given
    let formatter = try Formatter.selection(
      of: """
        * Parent
          * Child 11219
          * Sibling
        * Next
        """,
      from: "11219"
    )

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "11219\n\n  • Sibling\n\n  • Next")
  }

  @Test func partialBlockQuoteParagraphHasNoIndentation() throws {
    // given
    let formatter = try Formatter.selection(
      of: "> Quoted 11219 text\n>\n> Second paragraph", from: "11219")

    // when
    let result = formatter.plainText()

    // then
    #expect(result == "11219 text\n\n  Second paragraph")
  }
}

extension Textual.Formatter {
  /// The formatter for the text a selection starting at `start` (and ending before `end`, or at
  /// the end) holds, as `attributedText(in:)` hands it over.
  static func selection(
    of markdown: String,
    from start: String,
    to end: String? = nil,
    startsMidBlock: Bool = true
  ) throws -> Textual.Formatter {
    let text = try NSAttributedString(markdown: markdown)
    let string = text.string as NSString
    let lowerBound = string.range(of: start).location
    let upperBound = end.map { string.range(of: $0).location } ?? string.length
    return Formatter(
      text.attributedSubstring(from: NSRange(location: lowerBound, length: upperBound - lowerBound)),
      startsMidBlock: startsMidBlock
    )
  }
}
