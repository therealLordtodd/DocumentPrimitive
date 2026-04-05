import CoreGraphics
import ExportKit
import Foundation
import PaginationPrimitive
import SwiftUI

struct ExportPageMetrics: Sendable, Equatable {
    var sectionStartPages: [Int]
    var totalPageCount: Int
}

struct ExportPageMetricsResolver: Sendable {
    func resolve(document: ExportableDocument) async -> ExportPageMetrics {
        guard !document.sections.isEmpty else {
            return ExportPageMetrics(sectionStartPages: [], totalPageCount: 1)
        }

        var sectionStartPages: [Int] = []
        var nextPageNumber = 1

        for (sectionIndex, section) in document.sections.enumerated() {
            let startPage = max(section.startPageNumber ?? nextPageNumber, 1)
            let template = pageTemplate(from: section.pageTemplate)
            let descriptors = measuredBlocks(
                for: section.blocks,
                template: template,
                footnotes: section.footnotes,
                footnoteConfiguration: document.footnoteConfiguration
            )
            let provider = ExportSectionTemplateProvider(
                template: template,
                headerFooter: section.headerFooter,
                startPageNumber: startPage
            )
            let pages = await paginate(
                descriptors: descriptors,
                templateProvider: provider,
                sectionIndex: sectionIndex
            )
            let pageCount = max(pages.count, 1)

            sectionStartPages.append(startPage)
            nextPageNumber = startPage + pageCount
        }

        return ExportPageMetrics(
            sectionStartPages: sectionStartPages,
            totalPageCount: max(nextPageNumber - 1, 1)
        )
    }

    private func paginate(
        descriptors: [MeasuredExportPageBlock],
        templateProvider: any PageTemplateProvider,
        sectionIndex: Int
    ) async -> [PaginationPrimitive.ComputedPage] {
        let items = descriptors.map(\.item)
        return await MainActor.run {
            let engine = PaginationEngine(templateProvider: templateProvider)
            engine.paginate(items, section: sectionIndex)
            return engine.pages
        }
    }

    private func pageTemplate(from exportTemplate: ExportPageTemplate) -> PageTemplate {
        PageTemplate(
            size: exportTemplate.size,
            margins: EdgeInsets(
                top: exportTemplate.margins.top,
                leading: exportTemplate.margins.leading,
                bottom: exportTemplate.margins.bottom,
                trailing: exportTemplate.margins.trailing
            ),
            columns: exportTemplate.columns,
            columnSpacing: exportTemplate.columnSpacing,
            headerHeight: exportTemplate.headerHeight,
            footerHeight: exportTemplate.footerHeight
        )
    }

    private func measuredBlocks(
        for blocks: [ExportBlock],
        template: PageTemplate,
        footnotes: [ExportFootnote] = [],
        footnoteConfiguration: ExportFootnoteConfiguration? = nil
    ) -> [MeasuredExportPageBlock] {
        blocks.map { block in
            measuredBlock(
                for: block,
                template: template,
                footnotes: footnotes,
                footnoteConfiguration: footnoteConfiguration
            )
        }
    }

    private func measuredBlock(
        for block: ExportBlock,
        template: PageTemplate,
        footnotes: [ExportFootnote],
        footnoteConfiguration: ExportFootnoteConfiguration?
    ) -> MeasuredExportPageBlock {
        let horizontalInset: CGFloat = block.type == .blockQuote ? 18 : 0
        let availableWidth = max(template.contentWidth - horizontalInset - 8, 72)
        let anchoredFootnotes = footnotes.filter { $0.anchorSourceIdentifier == block.sourceIdentifier }
        let height = estimatedHeight(for: block, availableWidth: availableWidth, contentHeight: template.contentHeight)

        return MeasuredExportPageBlock(
            item: MeasuredItem(
                height: height,
                canBreakInternally: canBreakInternally(block),
                keepWithNext: block.type == .heading,
                footnoteReservation: footnoteReservation(
                    for: anchoredFootnotes,
                    configuration: footnoteConfiguration
                )
            )
        )
    }

    private func estimatedHeight(
        for block: ExportBlock,
        availableWidth: CGFloat,
        contentHeight: CGFloat
    ) -> CGFloat {
        switch block.content {
        case .divider:
            return 24
        case let .image(_, _, _, size):
            let declaredHeight = size?.height ?? 180
            let declaredWidth = max(size?.width ?? availableWidth, 1)
            let scaledHeight = declaredHeight * min(availableWidth / declaredWidth, 1)
            return min(max(scaledHeight, 120), max(contentHeight * 0.6, 120))
        case let .table(rows, _, caption):
            return CGFloat(max(rows.count, 1)) * 28 + (caption == nil ? 0 : 24)
        case let .heading(content, level):
            return estimatedTextHeight(
                for: content.plainText,
                availableWidth: availableWidth,
                lineHeight: max(28 - CGFloat(level - 1) * 2.5, 16)
            )
        case let .blockQuote(content):
            return estimatedTextHeight(for: content.plainText, availableWidth: availableWidth, lineHeight: 18)
        case let .codeBlock(code, _):
            return estimatedTextHeight(for: code, availableWidth: availableWidth, lineHeight: 14)
        case let .list(content, _, indentLevel):
            let indentWidth = CGFloat(indentLevel) * 18
            return estimatedTextHeight(
                for: content.plainText,
                availableWidth: max(availableWidth - indentWidth, 48),
                lineHeight: 18
            )
        case let .text(content):
            return estimatedTextHeight(for: content.plainText, availableWidth: availableWidth, lineHeight: 18)
        }
    }

    private func estimatedTextHeight(
        for text: String,
        availableWidth: CGFloat,
        lineHeight: CGFloat
    ) -> CGFloat {
        let charactersPerLine = max(Int(availableWidth / 7), 18)
        let lineCount = max(Int(ceil(Double(max(text.count, 1)) / Double(charactersPerLine))), 1)
        return CGFloat(lineCount) * lineHeight + 18
    }

    private func canBreakInternally(_ block: ExportBlock) -> Bool {
        switch block.content {
        case .text, .heading, .blockQuote, .codeBlock, .list:
            true
        case .table, .image, .divider:
            false
        }
    }

    private func footnoteReservation(
        for footnotes: [ExportFootnote],
        configuration: ExportFootnoteConfiguration?
    ) -> CGFloat {
        guard configuration?.placement == .pageBottom, !footnotes.isEmpty else { return 0 }

        return footnotes.reduce(CGFloat(12)) { partialResult, footnote in
            let lines = max(Int(ceil(Double(max(footnote.content.plainText.count, 1)) / 48.0)), 1)
            return partialResult + CGFloat(lines) * 14 + 6
        }
    }
}

private struct MeasuredExportPageBlock {
    var item: MeasuredItem
}

private struct ExportSectionTemplateProvider: PageTemplateProvider, Sendable {
    var template: PageTemplate
    var headerFooter: ExportHeaderFooterConfiguration?
    var startPageNumber: Int

    func template(forPage pageNumber: Int, isFirst: Bool, section: Int) -> PageTemplate {
        _ = section

        var adjusted = template
        let absolutePageNumber = startPageNumber + max(pageNumber - 1, 0)
        let pageIndex = max(pageNumber - 1, 0)
        let resolved = headerFooter?.resolvedHeaderFooter(
            pageNumber: absolutePageNumber,
            pageIndexInSection: isFirst ? 0 : pageIndex
        )

        adjusted.headerHeight = resolved?.header == nil ? 0 : template.headerHeight
        adjusted.footerHeight = resolved?.footer == nil ? 0 : template.footerHeight
        return adjusted
    }
}
