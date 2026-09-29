import Foundation

// MARK: - Overview
//
// Formatter converts AttributedString to structured block and inline nodes for export to
// plain text and HTML. The transformation happens in three stages.
//
// First, AttributedString runs are grouped by PresentationIntent, merging consecutive runs
// with identical intents into single segments.
//
// Then segments are recursively grouped by their intent component hierarchy, building
// a tree where container nodes have children and leaf nodes hold attributed substrings.
//
// Finally, the block tree is mapped to typed BlockNode and InlineNode enums that represent
// paragraphs, headers, lists, code blocks, tables, and inline formatting.
//
// The result is a semantic document structure suitable for rendering to various formats.

final class Formatter {
  lazy var blockNodes: [BlockNode] = makeBlockNodes()

  private let attributedString: AttributedString

  /// - Parameter startsMidBlock: The text is a selection that begins after the start of its first
  ///   block, so that block's list markers, indentation and heading level are not the reader's to
  ///   copy. See ``AttributedString/removingLeadingBlockDecoration()``.
  convenience init(_ nsAttributedString: NSAttributedString, startsMidBlock: Bool = false) {
    self.init(
      (try? AttributedString(
        nsAttributedString,
        including: \.textual
      )) ?? .init(),
      startsMidBlock: startsMidBlock
    )
  }

  init(_ attributedString: AttributedString, startsMidBlock: Bool = false) {
    self.attributedString =
      startsMidBlock
      ? attributedString.removingLeadingBlockDecoration()
      : attributedString
  }
}

// MARK: - Intermediate representation

extension Formatter {
  fileprivate func makeBlockNodes() -> [BlockNode] {
    attributedString.blockNodes
  }

  enum InlineNode: Hashable {
    case text(String)
    case code(String)
    case strong(children: [InlineNode])
    case emphasized(children: [InlineNode])
    case strikethrough(children: [InlineNode])
    case link(url: URL, children: [InlineNode])
    case lineBreak
    case attachment(AnyAttachment)
  }

  struct ListItem: Hashable {
    let ordinal: Int
    let blocks: [BlockNode]
  }

  struct TableRow: Hashable {
    let cells: [[InlineNode]]
  }

  enum BlockNode: Hashable {
    case paragraph(children: [InlineNode])
    case header(level: Int, children: [InlineNode])
    case orderedList(children: [ListItem])
    case unorderedList(children: [ListItem])
    case codeBlock(languageHint: String?, code: String)
    case blockQuote(children: [BlockNode])
    case table(columns: [PresentationIntent.TableColumn], children: [TableRow])
    case thematicBreak
  }
}

// MARK: - Hierarchical representation

extension Formatter {
  fileprivate struct Block: Equatable {
    struct Container: Equatable {
      let children: [Block]
    }

    struct Leaf: Equatable {
      let attributedString: AttributedSubstring
    }

    enum Kind: Equatable {
      case container(Container)
      case leaf(Leaf)
    }

    let intentType: PresentationIntent.IntentType
    let kind: Kind

    var container: Container? {
      guard case .container(let container) = self.kind else {
        return nil
      }
      return container
    }

    var leaf: Leaf? {
      guard case .leaf(let leaf) = self.kind else {
        return nil
      }
      return leaf
    }
  }
}

extension Formatter {
  fileprivate struct Segment {
    let components: ArraySlice<PresentationIntent.IntentType>
    let intent: PresentationIntent
    var range: Range<AttributedString.Index>

    init(intent: PresentationIntent, range: Range<AttributedString.Index>) {
      self.init(
        components: intent.components[intent.components.startIndex..<intent.components.endIndex],
        intent: intent,
        range: range
      )
    }

    private init(
      components: ArraySlice<PresentationIntent.IntentType>,
      intent: PresentationIntent,
      range: Range<AttributedString.Index>
    ) {
      self.components = components
      self.intent = intent
      self.range = range
    }

    func dropLastComponent() -> Self {
      .init(components: self.components.dropLast(), intent: self.intent, range: self.range)
    }
  }

  fileprivate struct SegmentGrouping {
    let component: PresentationIntent.IntentType
    var segments: [Segment]
  }
}

extension Sequence where Element == Formatter.Segment {
  fileprivate func groupedByLastComponent() -> [Formatter.SegmentGrouping] {
    var groups: [Formatter.SegmentGrouping] = []

    for segment in self {
      guard let component = segment.components.last else {
        continue
      }

      if groups.isEmpty || groups.last?.component != component {
        groups.append(.init(component: component, segments: [segment.dropLastComponent()]))
      } else {
        groups[groups.index(before: groups.endIndex)].segments.append(segment.dropLastComponent())
      }
    }

    return groups
  }
}

// MARK: - AttributedString segmentation

extension AttributedString {
  private func segments() -> [Formatter.Segment] {
    var segments: [Formatter.Segment] = []

    for run in self.runs {
      guard let presentationIntent = run.presentationIntent else {
        continue
      }

      if segments.isEmpty || segments.last?.intent != presentationIntent {
        segments.append(.init(intent: presentationIntent, range: run.range))
      } else {
        let lastIndex = segments.index(before: segments.endIndex)
        let currentRange = segments[lastIndex].range
        segments[lastIndex].range = currentRange.lowerBound..<run.range.upperBound
      }
    }

    if segments.isEmpty {
      segments.append(
        .init(
          intent: .init(.paragraph, identity: 1),
          range: self.startIndex..<self.endIndex
        )
      )
    }

    return segments
  }
}

extension AttributedString {
  fileprivate var blocks: [Formatter.Block] {
    self.segments().groupedByLastComponent()
      .map { .init(segmentGrouping: $0, attributedString: self) }
  }
}

// MARK: - Block tree building

extension Formatter.Block {
  fileprivate init(segmentGrouping: Formatter.SegmentGrouping, attributedString: AttributedString) {
    if let segment = segmentGrouping.segments.first, segment.components.isEmpty {
      self.init(
        intentType: segmentGrouping.component,
        kind: .leaf(
          .init(attributedString: attributedString[segment.range])
        )
      )
    } else {
      self.init(
        intentType: segmentGrouping.component,
        kind: .container(
          .init(
            children: segmentGrouping.segments.groupedByLastComponent().map {
              .init(segmentGrouping: $0, attributedString: attributedString)
            }
          )
        )
      )
    }
  }
}

// MARK: - Block tree to BlockNode conversion

extension Formatter.Block {
  var blockNode: Formatter.BlockNode? {
    switch intentType.kind {
    case .paragraph:
      guard let leaf else {
        return nil
      }
      return .paragraph(children: leaf.inlineNodes)
    case .header(let level):
      guard let leaf else {
        return nil
      }
      return .header(level: level, children: leaf.inlineNodes)
    case .orderedList:
      guard let container else {
        return nil
      }
      return .orderedList(children: container.listItems)
    case .unorderedList:
      guard let container else {
        return nil
      }
      return .unorderedList(children: container.listItems)
    case .codeBlock(let languageHint):
      guard let leaf else {
        return nil
      }
      return .codeBlock(
        languageHint: languageHint,
        code: String(leaf.attributedString.characters[...])
      )
    case .blockQuote:
      guard let container else {
        return nil
      }
      return .blockQuote(children: container.children.compactMap(\.blockNode))
    case .table(let columns):
      guard let container else {
        return nil
      }
      return .table(columns: columns, children: container.tableRows)
    case .thematicBreak:
      return .thematicBreak
    default:
      return nil
    }
  }
}

extension Formatter.Block.Container {
  var listItems: [Formatter.ListItem] {
    children.compactMap { block in
      guard
        case .listItem(let ordinal) = block.intentType.kind,
        let container = block.container
      else {
        return nil
      }
      return .init(
        ordinal: ordinal,
        blocks: container.children.compactMap(\.blockNode)
      )
    }
  }

  var tableRows: [Formatter.TableRow] {
    children.compactMap { block in
      guard
        block.intentType.kind.isTableRow,
        let container = block.container
      else {
        return nil
      }
      return .init(
        cells: container.children.compactMap(\.leaf?.inlineNodes)
      )
    }
  }
}

extension Formatter.Block.Leaf {
  var inlineNodes: [Formatter.InlineNode] {
    self.attributedString.runs
      .map { self.attributedString[$0.range] }
      .map(Formatter.InlineNode.init)
  }
}

extension PresentationIntent.Kind {
  fileprivate var isTableRow: Bool {
    switch self {
    case .tableHeaderRow, .tableRow:
      return true
    default:
      return false
    }
  }
}

// MARK: - InlineNode construction

extension Formatter.InlineNode {
  fileprivate init(_ attributedString: AttributedSubstring) {
    let intent = attributedString.inlinePresentationIntent ?? []

    var node: Self

    if let attachment = attributedString.textual.attachment {
      node = .attachment(attachment)
    } else if intent.contains(.lineBreak) {
      node = .lineBreak
    } else if intent.contains(.softBreak) {
      node = .text(" ")
    } else if intent.contains(.code) {
      node = .code(String(attributedString.characters[...]))
    } else {
      node = .text(String(attributedString.characters[...]))
    }

    if intent.contains(.stronglyEmphasized) {
      node = .strong(children: [node])
    }

    if intent.contains(.emphasized) {
      node = .emphasized(children: [node])
    }

    if intent.contains(.strikethrough) {
      node = .strikethrough(children: [node])
    }

    if let url = attributedString.link {
      node = .link(url: url, children: [node])
    }

    self = node
  }
}

// MARK: - Selections that begin inside a block

extension AttributedString {
  /// Rewrites the presentation intents of the leading runs so that the block the text begins in
  /// no longer carries the decoration of the containers whose start is not part of the text.
  ///
  /// A list marker (and the indentation that goes with it) belongs to a list item only when the
  /// item's start is copied: selecting `11219` inside `* 11219` copies `11219`, not `  • 11219`.
  /// Every list item that contains the first run began before the text, so each loses its marker;
  /// items that follow keep theirs. For the runs that still sit inside the first run's outermost
  /// list item, the components from the deepest item they share with the first run outwards (that
  /// item, its list, enclosing items, lists and block quotes) are dropped, and what is inside that
  /// item (its paragraphs, nested lists) is kept. Outside a list, the first block alone loses its
  /// enclosing block quotes. A heading the text begins inside becomes a paragraph.
  ///
  /// Text that begins in a table cell or any other leaf that is not a paragraph, heading or code
  /// block is returned unchanged.
  fileprivate func removingLeadingBlockDecoration() -> AttributedString {
    guard
      let chain = runs.lazy.compactMap(\.presentationIntent).first?.components,
      let leaf = chain.first
    else {
      return self
    }

    switch leaf.kind {
    case .paragraph, .header, .codeBlock:
      break
    default:
      return self
    }

    // Innermost first, like `components`. Without a list, the anchor is the block itself.
    let items = chain.filter {
      if case .listItem = $0.kind { return true }
      return false
    }
    let anchors = items.isEmpty ? [leaf] : items
    guard let outermost = anchors.last else {
      return self
    }

    let bareLeaf: PresentationIntent.IntentType
    if case .header = leaf.kind {
      bareLeaf = PresentationIntent(.paragraph, identity: leaf.identity).components[0]
    } else {
      bareLeaf = leaf
    }

    var result = self
    for run in runs {
      guard let intent = run.presentationIntent else {
        continue
      }
      let components = intent.components
      guard components.contains(outermost) else {
        break
      }
      guard let cut = components.firstIndex(where: { anchors.contains($0) }) else {
        break
      }

      var kept = Array(components[..<cut])
      if kept.isEmpty {
        kept = [components[cut]]
      }
      kept = kept.map { $0 == leaf ? bareLeaf : $0 }

      result[run.range].presentationIntent = kept.reversed().reduce(PresentationIntent?.none) {
        PresentationIntent($1.kind, identity: $1.identity, parent: $0)
      }
    }
    return result
  }
}

// MARK: - Highest-level conveniences

extension AttributedString {
  fileprivate var blockNodes: [Formatter.BlockNode] {
    self.blocks.compactMap(\.blockNode)
  }
}
