import DocumentPrimitive
import ExportKit
import Foundation
import PaginationPrimitive
import RichTextPrimitive

public struct BlockToExportMapper: Sendable {
    public init() {}

    public func map(block: Block) -> ExportBlock {
        ExportBlock(
            sourceIdentifier: block.id.rawValue,
            type: exportType(for: block.type),
            content: exportContent(for: block.content)
        )
    }

    public func map(blocks: [Block]) -> [ExportBlock] {
        blocks.map(map(block:))
    }

    public func map(document: Document) -> ExportableDocument {
        let blocks = map(blocks: document.sections.flatMap(\.blocks))
        let sections = document.sections.map { map(section: $0, settings: document.settings) }
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

        return ExportableDocument(
            blocks: blocks,
            metadata: metadata,
            sections: sections,
            footnoteConfiguration: exportFootnoteConfiguration(document.settings.footnoteConfig),
            images: images
        )
    }

    public func map(section: DocumentSection, settings: DocumentSettings) -> ExportSection {
        let layout = section.columnLayout ?? .single
        let headerFooter = exportHeaderFooterConfiguration(section.headerFooter)
        let pageSetup = section.pageSetup ?? settings.defaultPageSetup
        let template = pageSetup.pageTemplate(
            columns: layout.columns,
            columnSpacing: layout.spacing,
            headerHeight: headerFooter?.hasAnyHeaderContent == true ? 36 : 0,
            footerHeight: headerFooter?.hasAnyFooterContent == true ? 28 : 0
        )

        return ExportSection(
            blocks: map(blocks: section.blocks),
            pageTemplate: exportPageTemplate(template),
            headerFooter: headerFooter,
            footnotes: section.footnotes.map(exportFootnote(_:)),
            startPageNumber: section.startPageNumber
        )
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
            .table(
                rows: table.rows.map { row in row.map(exportTextContent(from:)) },
                columnWidths: table.columnWidths,
                caption: table.caption.map(exportTextContent(from:))
            )
        case let .image(image):
            .image(data: image.data, url: image.url, altText: image.altText, size: image.size)
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

    private func exportTextContent(from runs: [TextRun]) -> ExportTextContent {
        ExportTextContent(
            runs: runs.map { run in
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

    private func exportHeaderFooterConfiguration(_ config: HeaderFooterConfig?) -> ExportHeaderFooterConfiguration? {
        guard let config else { return nil }

        return ExportHeaderFooterConfiguration(
            firstHeader: config.firstHeader.map(exportHeaderFooter(_:)),
            firstFooter: config.firstFooter.map(exportHeaderFooter(_:)),
            header: config.header.map(exportHeaderFooter(_:)),
            footer: config.footer.map(exportHeaderFooter(_:)),
            evenHeader: config.evenHeader.map(exportHeaderFooter(_:)),
            evenFooter: config.evenFooter.map(exportHeaderFooter(_:)),
            differentFirstPage: config.differentFirstPage,
            differentOddEven: config.differentOddEven
        )
    }

    private func exportHeaderFooter(_ headerFooter: HeaderFooter) -> ExportHeaderFooter {
        ExportHeaderFooter(
            left: exportTextContent(from: headerFooter.left),
            center: exportTextContent(from: headerFooter.center),
            right: exportTextContent(from: headerFooter.right)
        )
    }

    private func exportPageTemplate(_ template: PageTemplate) -> ExportPageTemplate {
        ExportPageTemplate(
            size: template.size,
            margins: ExportPageMargins(
                top: template.margins.top,
                leading: template.margins.leading,
                bottom: template.margins.bottom,
                trailing: template.margins.trailing
            ),
            columns: template.columns,
            columnSpacing: template.columnSpacing,
            headerHeight: template.headerHeight,
            footerHeight: template.footerHeight
        )
    }

    private func exportFootnoteConfiguration(_ config: FootnoteConfig) -> ExportFootnoteConfiguration {
        let placement: ExportFootnotePlacement
        switch config.placement {
        case .pageBottom:
            placement = .pageBottom
        case .sectionEnd:
            placement = .sectionEnd
        case .documentEnd:
            placement = .documentEnd
        }

        return ExportFootnoteConfiguration(
            placement: placement,
            numberingStyle: exportNumberingStyle(config.numberingStyle),
            restartPerSection: config.restartPerSection
        )
    }

    private func exportFootnote(_ footnote: Footnote) -> ExportFootnote {
        ExportFootnote(
            anchorSourceIdentifier: footnote.anchorBlockID.rawValue,
            content: exportTextContent(from: footnote.content)
        )
    }

    private func exportNumberingStyle(_ style: NumberingStyle) -> ExportNumberingStyle {
        switch style {
        case .arabic:
            .arabic
        case .roman:
            .roman
        case .alpha:
            .alpha
        case .symbol:
            .symbol
        }
    }
}
