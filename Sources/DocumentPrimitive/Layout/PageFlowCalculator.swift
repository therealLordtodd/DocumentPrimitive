import CoreGraphics
import Foundation
import PaginationPrimitive
import RichTextPrimitive

struct MeasuredBlockDescriptor: Sendable {
    var item: MeasuredItem
    var blockID: BlockID
    var blockIndex: Int
}

public struct PageFlowCalculator: Sendable {
    public init() {}

    func templateProvider(
        for section: DocumentSection,
        settings: DocumentSettings
    ) -> any PageTemplateProvider {
        SectionTemplateProvider(
            pageSetup: section.pageSetup ?? settings.defaultPageSetup,
            layout: section.columnLayout ?? .single,
            config: section.headerFooter
        )
    }

    func template(
        for section: DocumentSection,
        settings: DocumentSettings
    ) -> PageTemplate {
        templateProvider(for: section, settings: settings)
            .template(forPage: 1, isFirst: true, section: 0)
    }

    func measuredBlocks(
        for section: DocumentSection,
        settings: DocumentSettings
    ) -> [MeasuredBlockDescriptor] {
        let template = template(for: section, settings: settings)
        return section.blocks.enumerated().map { index, block in
            let anchoredFootnotes = section.footnotes.filter { $0.anchorBlockID == block.id }
            let height = estimatedHeight(for: block, contentWidth: template.columnWidth)
            let reservesPageFootnotes = settings.footnoteConfig.placement == .pageBottom
            let widowOrphanControl = paragraphControl(for: block)

            return MeasuredBlockDescriptor(
                item: MeasuredItem(
                    id: UUID(),
                    height: height,
                    canBreakInternally: block.type == .paragraph || block.type == .blockQuote || block.type == .list,
                    keepWithNext: block.type == .heading,
                    breakBefore: block.metadata.custom["pageBreakBefore"] == .bool(true),
                    breakAfter: block.metadata.custom["pageBreakAfter"] == .bool(true),
                    footnoteReservation: reservesPageFootnotes ? estimatedFootnoteHeight(for: anchoredFootnotes) : 0,
                    widowLines: widowOrphanControl.widowLines,
                    orphanLines: widowOrphanControl.orphanLines
                ),
                blockID: block.id,
                blockIndex: index
            )
        }
    }

    func headerFooter(
        for config: HeaderFooterConfig?,
        pageNumber: Int,
        pageIndexInSection: Int
    ) -> (header: HeaderFooter?, footer: HeaderFooter?) {
        guard let config else { return (nil, nil) }

        var header = config.header
        var footer = config.footer

        if config.differentFirstPage, pageIndexInSection == 0 {
            header = nil
            footer = nil
        } else if config.differentOddEven, pageNumber.isMultiple(of: 2) {
            header = header.map { HeaderFooter(left: $0.right, center: $0.center, right: $0.left) }
            footer = footer.map { HeaderFooter(left: $0.right, center: $0.center, right: $0.left) }
        }

        return (header, footer)
    }

    func footnotes(
        for section: DocumentSection,
        visibleBlockIDs: [BlockID],
        pageIndexInSection: Int,
        pageCountInSection: Int,
        isLastSection: Bool,
        settings: DocumentSettings
    ) -> [Footnote] {
        switch settings.footnoteConfig.placement {
        case .pageBottom:
            return section.footnotes.filter { visibleBlockIDs.contains($0.anchorBlockID) }
        case .sectionEnd:
            guard pageIndexInSection == pageCountInSection - 1 else { return [] }
            return section.footnotes
        case .documentEnd:
            guard isLastSection, pageIndexInSection == pageCountInSection - 1 else { return [] }
            return section.footnotes
        }
    }

    private func estimatedHeight(for block: Block, contentWidth: CGFloat) -> CGFloat {
        let lineHeight: CGFloat = switch block.type {
        case .heading:
            30
        case .codeBlock:
            18
        default:
            22
        }

        let textLength: Int = switch block.content {
        case let .text(content),
             let .heading(content, _),
             let .blockQuote(content),
             let .list(content, _, _):
            content.plainText.count
        case let .codeBlock(code, _):
            code.count
        case let .table(content):
            content.rows.flatMap { $0 }.map(\.plainText.count).reduce(0, +)
        case let .image(content):
            Int(content.size?.height ?? 180)
        case .divider:
            1
        case let .embed(content):
            content.payload?.count ?? 20
        }

        let charsPerLine = max(Int(contentWidth / 8), 20)
        let lines = max(Int(ceil(Double(max(textLength, 1)) / Double(charsPerLine))), 1)

        switch block.content {
        case let .table(content):
            return CGFloat(max(content.rows.count, 1)) * 28 + 24
        case let .image(content):
            return content.size?.height ?? 180
        case .divider:
            return 24
        case .embed:
            return 120
        default:
            return CGFloat(lines) * lineHeight + 12
        }
    }

    private func estimatedFootnoteHeight(for footnotes: [Footnote]) -> CGFloat {
        guard !footnotes.isEmpty else { return 0 }

        return footnotes.reduce(CGFloat(10)) { partialResult, footnote in
            let characters = max(footnote.content.plainText.count, 1)
            let lines = max(Int(ceil(Double(characters) / 48.0)), 1)
            return partialResult + CGFloat(lines) * 14 + 6
        }
    }

    private func paragraphControl(for block: Block) -> (widowLines: Int, orphanLines: Int) {
        switch block.type {
        case .paragraph, .blockQuote, .list:
            return (2, 2)
        default:
            return (0, 0)
        }
    }
}

private struct SectionTemplateProvider: PageTemplateProvider, Sendable {
    let pageSetup: PageSetup
    let layout: ColumnLayout
    let config: HeaderFooterConfig?

    func template(forPage pageNumber: Int, isFirst: Bool, section: Int) -> PageTemplate {
        _ = section

        let pageIndex = max(pageNumber - 1, 0)
        let resolved = Self.resolveHeaderFooter(
            config,
            pageNumber: pageNumber,
            pageIndexInSection: isFirst ? 0 : pageIndex
        )

        return pageSetup.pageTemplate(
            columns: layout.columns,
            columnSpacing: layout.spacing,
            headerHeight: resolved.header == nil ? 0 : 36,
            footerHeight: resolved.footer == nil ? 0 : 28
        )
    }

    private static func resolveHeaderFooter(
        _ config: HeaderFooterConfig?,
        pageNumber: Int,
        pageIndexInSection: Int
    ) -> (header: HeaderFooter?, footer: HeaderFooter?) {
        guard let config else { return (nil, nil) }

        var header = config.header
        var footer = config.footer

        if config.differentFirstPage, pageIndexInSection == 0 {
            header = nil
            footer = nil
        } else if config.differentOddEven, pageNumber.isMultiple(of: 2) {
            header = header.map { HeaderFooter(left: $0.right, center: $0.center, right: $0.left) }
            footer = footer.map { HeaderFooter(left: $0.right, center: $0.center, right: $0.left) }
        }

        return (header, footer)
    }
}
