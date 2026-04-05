import Foundation
import RichTextPrimitive

public struct BlockFragmentResolver: Sendable {
    public init() {}

    public func block(for block: Block, placement: BlockFragmentPlacement) -> Block {
        guard
            placement.isPartial,
            let partialRange = placement.partialRange,
            placement.itemHeight > 0
        else {
            return block
        }

        let content = resolvedContent(for: block.content, partialRange: partialRange, itemHeight: placement.itemHeight)
        return Block(id: block.id, type: block.type, content: content, metadata: block.metadata)
    }

    private func resolvedContent(
        for content: BlockContent,
        partialRange: ClosedRange<CGFloat>,
        itemHeight: CGFloat
    ) -> BlockContent {
        switch content {
        case let .text(textContent):
            return .text(sliced(textContent, partialRange: partialRange, itemHeight: itemHeight))
        case let .heading(textContent, level):
            return .heading(sliced(textContent, partialRange: partialRange, itemHeight: itemHeight), level: level)
        case let .blockQuote(textContent):
            return .blockQuote(sliced(textContent, partialRange: partialRange, itemHeight: itemHeight))
        case let .list(textContent, style, indentLevel):
            return .list(
                sliced(textContent, partialRange: partialRange, itemHeight: itemHeight),
                style: style,
                indentLevel: indentLevel
            )
        case let .codeBlock(code, language):
            return .codeBlock(
                code: sliced(code, partialRange: partialRange, itemHeight: itemHeight),
                language: language
            )
        case .table, .image, .divider, .embed:
            return content
        }
    }

    private func sliced(
        _ content: TextContent,
        partialRange: ClosedRange<CGFloat>,
        itemHeight: CGFloat
    ) -> TextContent {
        let totalCharacters = content.plainText.count
        let range = characterRange(
            totalCharacters: totalCharacters,
            partialRange: partialRange,
            itemHeight: itemHeight
        )
        guard range.lowerBound != 0 || range.upperBound != totalCharacters else { return content }

        let slice = content.sliced(range)
        return decorated(
            slice,
            leading: range.lowerBound > 0,
            trailing: range.upperBound < totalCharacters
        )
    }

    private func sliced(
        _ code: String,
        partialRange: ClosedRange<CGFloat>,
        itemHeight: CGFloat
    ) -> String {
        let characters = Array(code)
        let range = characterRange(
            totalCharacters: characters.count,
            partialRange: partialRange,
            itemHeight: itemHeight
        )
        guard range.lowerBound != 0 || range.upperBound != characters.count else { return code }

        var value = String(characters[range])
        if range.lowerBound > 0 {
            value = "…" + value
        }
        if range.upperBound < characters.count {
            value += "…"
        }
        return value
    }

    private func characterRange(
        totalCharacters: Int,
        partialRange: ClosedRange<CGFloat>,
        itemHeight: CGFloat
    ) -> Range<Int> {
        guard totalCharacters > 0 else { return 0..<0 }

        let lowerRatio = max(min(partialRange.lowerBound / itemHeight, 1), 0)
        let upperRatio = max(min(partialRange.upperBound / itemHeight, 1), lowerRatio)

        let lower = min(max(Int(floor(CGFloat(totalCharacters) * lowerRatio)), 0), totalCharacters)
        var upper = min(max(Int(ceil(CGFloat(totalCharacters) * upperRatio)), lower), totalCharacters)

        if upper == lower, upper < totalCharacters {
            upper += 1
        }

        return lower..<upper
    }

    private func decorated(
        _ content: TextContent,
        leading: Bool,
        trailing: Bool
    ) -> TextContent {
        guard leading || trailing else { return content }

        var runs = content.runs
        if leading {
            let attributes = runs.first?.attributes ?? .plain
            runs.insert(TextRun(text: "…", attributes: attributes), at: 0)
        }
        if trailing {
            let attributes = runs.last?.attributes ?? .plain
            runs.append(TextRun(text: "…", attributes: attributes))
        }
        return TextContent(runs: runs)
    }
}
