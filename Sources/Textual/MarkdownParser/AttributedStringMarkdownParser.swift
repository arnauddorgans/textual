import Foundation

/// A ``MarkupParser`` implementation backed by Foundation’s Markdown support.
///
/// This parser leverages Foundation’s Markdown support and preserves structure via
/// presentation intents.
///
/// This parser can process its output to expand custom emoji and math expressions into
/// inline attachments.
// Parsing is pure and touches nothing of the main actor: usable off it, as a document's rows are parsed before
// they are shown. Every stored value is immutable.
nonisolated public struct AttributedStringMarkdownParser: MarkupParser, @unchecked Sendable {
  private let baseURL: URL?
  private let options: AttributedString.MarkdownParsingOptions
  private let processor: PatternProcessor

  public init(
    baseURL: URL?,
    options: AttributedString.MarkdownParsingOptions = .init(),
    syntaxExtensions: [SyntaxExtension] = []
  ) {
    self.baseURL = baseURL
    self.options = options
    self.processor = PatternProcessor(syntaxExtensions: syntaxExtensions)
  }

  public func attributedString(for input: String) throws -> AttributedString {
    try processor.expand(
      AttributedString(
        markdown: input,
        including: \.textual,
        options: options,
        baseURL: baseURL
      )
    )
  }
}

extension MarkupParser where Self == AttributedStringMarkdownParser {
  /// Creates a Markdown parser configured for inline-only syntax.
  public static func inlineMarkdown(
    baseURL: URL? = nil,
    syntaxExtensions: [AttributedStringMarkdownParser.SyntaxExtension] = []
  ) -> Self {
    .init(
      baseURL: baseURL,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace),
      syntaxExtensions: syntaxExtensions
    )
  }

  /// Creates a Markdown parser configured for full-document syntax.
  public static func markdown(
    baseURL: URL? = nil,
    syntaxExtensions: [AttributedStringMarkdownParser.SyntaxExtension] = []
  ) -> Self {
    .init(
      baseURL: baseURL,
      syntaxExtensions: syntaxExtensions
    )
  }
}
