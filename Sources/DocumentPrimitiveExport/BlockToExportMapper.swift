import DocumentPrimitive
import ExportKit
import Foundation
import RichTextPrimitive

public struct BlockToExportMapper: Sendable {
    public init() {}

    public func map(block: Block) -> ExportBlock {
        ExportBlock(type: exportType(for: block.type), content: exportContent(for: block.content))
    }

    public func map(blocks: [Block]) -> [ExportBlock] {
        blocks.map(map(block:))
    }

    public func map(document: Document) -> ExportableDocument {
        let blocks = map(blocks: document.sections.flatMap(\.blocks))
        let metadata = DocumentMetadata(
            title: document.title,
            author: document.settings.author,
            createdAt: document.settings.createdAt,
            modifiedAt: document.settings.modifiedAt
        )
        let images = document.sections
            .flatMap(\.blocks)
            .reduce(into: [UUID: Data]()) { partialResult, block in
                if case let .image(content) = block.content, let data = content.data {
                    partialResult[content.imageID] = data
                }
            }

        return ExportableDocument(blocks: blocks, metadata: metadata, images: images)
    }

    private func exportType(for type: BlockType) -> ExportBlockType {
        switch type {
        case .paragraph:
            .paragraph
        case .heading:
            .heading
        case .blockQuote:
            .blockQuote
        case .codeBlock:
            .codeBlock
        case .list:
            .list
        case .table:
            .table
        case .image:
            .image
        case .divider:
            .divider
        case .embed:
            .paragraph
        }
    }

    private func exportContent(for content: BlockContent) -> ExportBlockContent {
        switch content {
        case let .text(textContent):
            .text(exportTextContent(from: textContent))
        case let .heading(textContent, level):
            .heading(exportTextContent(from: textContent), level: level)
        case let .blockQuote(textContent):
            .blockQuote(exportTextContent(from: textContent))
        case let .codeBlock(code, language):
            .codeBlock(code: code, language: language)
        case let .list(textContent, style, indentLevel):
            .list(exportTextContent(from: textContent), ordered: style == .numbered, indentLevel: indentLevel)
        case let .table(table):
            .table(rows: table.rows.map { row in row.map(exportTextContent(from:)) })
        case let .image(image):
            .image(data: image.data, url: image.url, altText: image.altText)
        case .divider:
            .divider
        case let .embed(embed):
            .text(.plain(embed.payload ?? "[\(embed.kind)]"))
        }
    }

    private func exportTextContent(from content: TextContent) -> ExportTextContent {
        ExportTextContent(
            runs: content.runs.map { run in
                ExportTextRun(
                    text: run.text,
                    bold: run.attributes.bold,
                    italic: run.attributes.italic,
                    underline: run.attributes.underline,
                    strikethrough: run.attributes.strikethrough,
                    code: run.attributes.code,
                    link: run.attributes.link
                )
            }
        )
    }
}
