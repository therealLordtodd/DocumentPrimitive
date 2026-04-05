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

    func template(
        for section: DocumentSection,
        settings: DocumentSettings
    ) -> PageTemplate {
        let pageSetup = section.pageSetup ?? settings.defaultPageSetup
        let layout = section.columnLayout ?? .single
        let config = section.headerFooter

        return pageSetup.pageTemplate(
            columns: layout.columns,
            columnSpacing: layout.spacing,
            headerHeight: config?.header == nil ? 0 : 36,
            footerHeight: config?.footer == nil ? 0 : 28
        )
    }

    func measuredBlocks(
        for section: DocumentSection,
        settings: DocumentSettings
    ) -> [MeasuredBlockDescriptor] {
        let template = template(for: section, settings: settings)
        return section.blocks.enumerated().map { index, block in
            let footnoteCount = section.footnotes.filter { $0.anchorBlockID == block.id }.count
            let height = estimatedHeight(
                for: block,
                contentWidth: template.columnWidth
            ) + (CGFloat(footnoteCount) * 20)

            return MeasuredBlockDescriptor(
                item: MeasuredItem(
                    id: UUID(),
                    height: height,
                    canBreakInternally: block.type == .paragraph || block.type == .blockQuote || block.type == .list,
                    keepWithNext: block.type == .heading,
                    breakBefore: block.metadata.custom["pageBreakBefore"] == .bool(true),
                    breakAfter: block.metadata.custom["pageBreakAfter"] == .bool(true)
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
}
