import Foundation
import RichTextPrimitive

public struct BlockFragmentEditResolver: Sendable {
    public init() {}

    public func characterRange(
        for block: Block,
        placement: BlockFragmentPlacement
    ) -> Range<Int>? {
        guard
            placement.isPartial,
            let partialRange = placement.partialRange,
            placement.itemHeight > 0
        else {
            return 0..<editableCharacterCount(for: block)
        }

        return characterRange(
            totalCharacters: editableCharacterCount(for: block),
            partialRange: partialRange,
            itemHeight: placement.itemHeight
        )
    }

    public func fragmentBlock(
        for block: Block,
        placement: BlockFragmentPlacement
    ) -> Block? {
        guard let range = characterRange(for: block, placement: placement) else { return nil }
        let content = fragmentContent(for: block.content, range: range)
        return Block(id: block.id, type: block.type, content: content, metadata: block.metadata)
    }

    public func mergedBlocks(
        replacing placement: BlockFragmentPlacement,
        in original: Block,
        with replacementBlocks: [Block]
    ) -> [Block] {
        switch original.content {
        case let .text(content):
            return mergeTextLikeBlocks(
                original: original,
                originalContent: content,
                placement: placement,
                replacementBlocks: replacementBlocks
            )
        case let .heading(content, _):
            return mergeTextLikeBlocks(
                original: original,
                originalContent: content,
                placement: placement,
                replacementBlocks: replacementBlocks
            )
        case let .blockQuote(content):
            return mergeTextLikeBlocks(
                original: original,
                originalContent: content,
                placement: placement,
                replacementBlocks: replacementBlocks
            )
        case let .list(content, _, _):
            return mergeTextLikeBlocks(
                original: original,
                originalContent: content,
                placement: placement,
                replacementBlocks: replacementBlocks
            )
        case let .codeBlock(code, _):
            return mergeCodeBlocks(
                original: original,
                originalCode: code,
                placement: placement,
                replacementBlocks: replacementBlocks
            )
        case .table, .image, .divider, .embed:
            return replacementBlocks.isEmpty ? [original] : replacementBlocks
        }
    }

    private func fragmentContent(
        for content: BlockContent,
        range: Range<Int>
    ) -> BlockContent {
        switch content {
        case let .text(textContent):
            return .text(textContent.sliced(range))
        case let .heading(textContent, level):
            return .heading(textContent.sliced(range), level: level)
        case let .blockQuote(textContent):
            return .blockQuote(textContent.sliced(range))
        case let .list(textContent, style, indentLevel):
            return .list(textContent.sliced(range), style: style, indentLevel: indentLevel)
        case let .codeBlock(code, language):
            let characters = Array(code)
            let lower = min(max(range.lowerBound, 0), characters.count)
            let upper = min(max(range.upperBound, lower), characters.count)
            return .codeBlock(code: String(characters[lower..<upper]), language: language)
        case .table, .image, .divider, .embed:
            return content
        }
    }

    private func mergeTextLikeBlocks(
        original: Block,
        originalContent: TextContent,
        placement: BlockFragmentPlacement,
        replacementBlocks: [Block]
    ) -> [Block] {
        let range = characterRange(for: original, placement: placement) ?? 0..<originalContent.plainText.count
        let prefix = originalContent.sliced(0..<range.lowerBound)
        let suffix = originalContent.sliced(range.upperBound..<originalContent.plainText.count)

        guard !replacementBlocks.isEmpty else {
            let merged = join(prefix, suffix)
            return [blockPreservingIdentity(from: original, content: merged.isEmpty ? emptyContent(like: original) : contentLike(original, textContent: merged))]
        }

        var result = replacementBlocks
        var prefixBlock: Block?
        var suffixBlock: Block?

        if !prefix.isEmpty {
            if let merged = prepending(prefix, to: result[0]) {
                result[0] = merged
            } else {
                prefixBlock = blockPreservingIdentity(from: original, content: contentLike(original, textContent: prefix))
            }
        }

        if !suffix.isEmpty {
            let lastIndex = result.count - 1
            if let merged = appending(suffix, to: result[lastIndex]) {
                result[lastIndex] = merged
            } else {
                suffixBlock = Block(type: original.type, content: contentLike(original, textContent: suffix))
            }
        }

        if let prefixBlock {
            result.insert(prefixBlock, at: 0)
        }
        if let suffixBlock {
            result.append(suffixBlock)
        }

        if result.isEmpty {
            return [blockPreservingIdentity(from: original, content: emptyContent(like: original))]
        }

        result[0] = blockPreservingIdentity(from: original, content: result[0].content, type: result[0].type)
        return result
    }

    private func mergeCodeBlocks(
        original: Block,
        originalCode: String,
        placement: BlockFragmentPlacement,
        replacementBlocks: [Block]
    ) -> [Block] {
        let range = characterRange(for: original, placement: placement) ?? 0..<originalCode.count
        let characters = Array(originalCode)
        let prefix = String(characters[..<min(range.lowerBound, characters.count)])
        let suffix = String(characters[min(range.upperBound, characters.count)...])

        guard !replacementBlocks.isEmpty else {
            let merged = prefix + suffix
            return [blockPreservingIdentity(
                from: original,
                content: merged.isEmpty ? emptyContent(like: original) : .codeBlock(code: merged, language: codeLanguage(from: original))
            )]
        }

        var result = replacementBlocks
        var prefixBlock: Block?
        var suffixBlock: Block?

        if !prefix.isEmpty {
            if let merged = prepending(prefix, to: result[0]) {
                result[0] = merged
            } else {
                prefixBlock = blockPreservingIdentity(
                    from: original,
                    content: .codeBlock(code: prefix, language: codeLanguage(from: original))
                )
            }
        }

        if !suffix.isEmpty {
            let lastIndex = result.count - 1
            if let merged = appending(suffix, to: result[lastIndex]) {
                result[lastIndex] = merged
            } else {
                suffixBlock = Block(type: .codeBlock, content: .codeBlock(code: suffix, language: codeLanguage(from: original)))
            }
        }

        if let prefixBlock {
            result.insert(prefixBlock, at: 0)
        }
        if let suffixBlock {
            result.append(suffixBlock)
        }

        if result.isEmpty {
            return [blockPreservingIdentity(from: original, content: emptyContent(like: original))]
        }

        result[0] = blockPreservingIdentity(from: original, content: result[0].content, type: result[0].type)
        return result
    }

    private func prepending(_ prefix: TextContent, to block: Block) -> Block? {
        switch block.content {
        case let .text(content):
            return Block(id: block.id, type: .paragraph, content: .text(join(prefix, content)), metadata: block.metadata)
        case let .heading(content, level):
            return Block(id: block.id, type: .heading, content: .heading(join(prefix, content), level: level), metadata: block.metadata)
        case let .blockQuote(content):
            return Block(id: block.id, type: .blockQuote, content: .blockQuote(join(prefix, content)), metadata: block.metadata)
        case let .list(content, style, indentLevel):
            return Block(
                id: block.id,
                type: .list,
                content: .list(join(prefix, content), style: style, indentLevel: indentLevel),
                metadata: block.metadata
            )
        case let .codeBlock(code, language):
            return Block(id: block.id, type: .codeBlock, content: .codeBlock(code: prefix.plainText + code, language: language), metadata: block.metadata)
        case .table, .image, .divider, .embed:
            return nil
        }
    }

    private func appending(_ suffix: TextContent, to block: Block) -> Block? {
        switch block.content {
        case let .text(content):
            return Block(id: block.id, type: .paragraph, content: .text(join(content, suffix)), metadata: block.metadata)
        case let .heading(content, level):
            return Block(id: block.id, type: .heading, content: .heading(join(content, suffix), level: level), metadata: block.metadata)
        case let .blockQuote(content):
            return Block(id: block.id, type: .blockQuote, content: .blockQuote(join(content, suffix)), metadata: block.metadata)
        case let .list(content, style, indentLevel):
            return Block(
                id: block.id,
                type: .list,
                content: .list(join(content, suffix), style: style, indentLevel: indentLevel),
                metadata: block.metadata
            )
        case let .codeBlock(code, language):
            return Block(id: block.id, type: .codeBlock, content: .codeBlock(code: code + suffix.plainText, language: language), metadata: block.metadata)
        case .table, .image, .divider, .embed:
            return nil
        }
    }

    private func prepending(_ prefix: String, to block: Block) -> Block? {
        switch block.content {
        case let .text(content):
            return Block(id: block.id, type: .paragraph, content: .text(.plain(prefix).appending(content)), metadata: block.metadata)
        case let .heading(content, level):
            return Block(id: block.id, type: .heading, content: .heading(.plain(prefix).appending(content), level: level), metadata: block.metadata)
        case let .blockQuote(content):
            return Block(id: block.id, type: .blockQuote, content: .blockQuote(.plain(prefix).appending(content)), metadata: block.metadata)
        case let .list(content, style, indentLevel):
            return Block(
                id: block.id,
                type: .list,
                content: .list(.plain(prefix).appending(content), style: style, indentLevel: indentLevel),
                metadata: block.metadata
            )
        case let .codeBlock(code, language):
            return Block(id: block.id, type: .codeBlock, content: .codeBlock(code: prefix + code, language: language), metadata: block.metadata)
        case .table, .image, .divider, .embed:
            return nil
        }
    }

    private func appending(_ suffix: String, to block: Block) -> Block? {
        switch block.content {
        case let .text(content):
            return Block(id: block.id, type: .paragraph, content: .text(content.appending(.plain(suffix))), metadata: block.metadata)
        case let .heading(content, level):
            return Block(id: block.id, type: .heading, content: .heading(content.appending(.plain(suffix)), level: level), metadata: block.metadata)
        case let .blockQuote(content):
            return Block(id: block.id, type: .blockQuote, content: .blockQuote(content.appending(.plain(suffix))), metadata: block.metadata)
        case let .list(content, style, indentLevel):
            return Block(
                id: block.id,
                type: .list,
                content: .list(content.appending(.plain(suffix)), style: style, indentLevel: indentLevel),
                metadata: block.metadata
            )
        case let .codeBlock(code, language):
            return Block(id: block.id, type: .codeBlock, content: .codeBlock(code: code + suffix, language: language), metadata: block.metadata)
        case .table, .image, .divider, .embed:
            return nil
        }
    }

    private func blockPreservingIdentity(
        from original: Block,
        content: BlockContent,
        type: BlockType? = nil
    ) -> Block {
        Block(
            id: original.id,
            type: type ?? original.type,
            content: content,
            metadata: original.metadata
        )
    }

    private func contentLike(_ original: Block, textContent: TextContent) -> BlockContent {
        switch original.content {
        case .text:
            return .text(textContent)
        case let .heading(_, level):
            return .heading(textContent, level: level)
        case .blockQuote:
            return .blockQuote(textContent)
        case let .list(_, style, indentLevel):
            return .list(textContent, style: style, indentLevel: indentLevel)
        case let .codeBlock(_, language):
            return .codeBlock(code: textContent.plainText, language: language)
        case .table, .image, .divider, .embed:
            return .text(textContent)
        }
    }

    private func emptyContent(like original: Block) -> BlockContent {
        switch original.content {
        case .codeBlock:
            return .codeBlock(code: "", language: codeLanguage(from: original))
        case .text, .heading, .blockQuote, .list:
            return contentLike(original, textContent: .plain(""))
        case .table, .image, .divider, .embed:
            return .text(.plain(""))
        }
    }

    private func editableCharacterCount(for block: Block) -> Int {
        switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            return content.plainText.count
        case let .codeBlock(code, _):
            return code.count
        case .table, .image, .divider, .embed:
            return 0
        }
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

    private func join(_ lhs: TextContent, _ rhs: TextContent) -> TextContent {
        TextContent(runs: lhs.runs + rhs.runs)
    }

    private func codeLanguage(from original: Block) -> String? {
        if case let .codeBlock(_, language) = original.content {
            return language
        }
        return nil
    }
}

private extension TextContent {
    func appending(_ other: TextContent) -> TextContent {
        TextContent(runs: runs + other.runs)
    }
}
