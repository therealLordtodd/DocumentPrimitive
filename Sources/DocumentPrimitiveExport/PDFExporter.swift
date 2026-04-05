import CoreGraphics
import CoreText
import ExportKit
import Foundation
import PaginationPrimitive
import SwiftUI
import UniformTypeIdentifiers

public struct PDFExporter: DocumentExporter {
    public let formatID = "pdf"
    public let fileExtension = "pdf"
    public let utType = UTType.pdf

    public init() {}

    public func export(_ document: ExportableDocument, options: ExportOptions) async throws -> Data {
        let pages = if document.sections.isEmpty {
            try await prepareFlatPages(for: document, options: options)
        } else {
            try await prepareSectionedPages(for: document, options: options)
        }

        let renderPages = pages.isEmpty ? [PreparedPDFPage.fallback(for: document, includeMetadata: options.includeMetadata)] : pages
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: renderPages[0].template.size)

        guard
            let consumer = CGDataConsumer(data: data),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetadata(for: document) as CFDictionary)
        else {
            return Data()
        }

        for page in renderPages {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(origin: .zero, size: page.template.size))

            context.saveGState()
            context.translateBy(x: 0, y: page.template.size.height)
            context.scaleBy(x: 1, y: -1)

            drawPageChrome(
                context: context,
                page: page,
                document: document,
                includeMetadata: options.includeMetadata
            )

            let contentRect = CGRect(
                x: page.template.margins.leading,
                y: page.template.margins.top + page.template.headerHeight,
                width: page.template.contentWidth,
                height: page.template.contentHeight
            )

            for placement in page.placements {
                guard let descriptor = page.descriptorByID[placement.itemID] else { continue }
                draw(
                    descriptor: descriptor,
                    placement: placement,
                    in: contentRect,
                    context: context
                )
            }

            if !page.footnotes.isEmpty {
                drawFootnotes(
                    page.footnotes,
                    in: contentRect,
                    context: context,
                    page: page,
                    document: document
                )
            }

            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()
        return data as Data
    }

    private func prepareFlatPages(
        for document: ExportableDocument,
        options: ExportOptions
    ) async throws -> [PreparedPDFPage] {
        let template = fallbackTemplate(includeMetadata: options.includeMetadata)
        let descriptors = measuredBlocks(for: document.blocks, template: template)
        let pages = try await paginate(
            descriptors: descriptors,
            templateProvider: UniformTemplateProvider(template: template),
            sectionIndex: 0
        )

        let rawPages = pages.isEmpty ? [PaginationPrimitive.ComputedPage(pageNumber: 1, template: template)] : pages
        let descriptorByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.item.id, $0) })

        return rawPages.enumerated().map { index, page in
            PreparedPDFPage(
                pageNumber: index + 1,
                pageCount: rawPages.count,
                sectionNumber: 1,
                pageIndexInSection: index,
                template: page.template,
                placements: page.placements,
                descriptorByID: descriptorByID,
                headerFooter: nil,
                footnotes: []
            )
        }
    }

    private func prepareSectionedPages(
        for document: ExportableDocument,
        options: ExportOptions
    ) async throws -> [PreparedPDFPage] {
        var prepared: [PreparedPDFPage] = []
        var nextPageNumber = 1
        let footnoteConfiguration = document.footnoteConfiguration

        for (sectionIndex, section) in document.sections.enumerated() {
            let template = pageTemplate(from: section.pageTemplate)
            let descriptors = measuredBlocks(
                for: section.blocks,
                template: template,
                footnotes: section.footnotes,
                footnoteConfiguration: footnoteConfiguration
            )
            let provider = SectionTemplateProvider(template: template, headerFooter: section.headerFooter)
            let pages = try await paginate(
                descriptors: descriptors,
                templateProvider: provider,
                sectionIndex: sectionIndex
            )
            let descriptorByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.item.id, $0) })
            let rawPages = pages.isEmpty ? [PaginationPrimitive.ComputedPage(pageNumber: 1, template: provider.template(forPage: 1, isFirst: true, section: sectionIndex))] : pages
            let sectionStart = section.startPageNumber ?? nextPageNumber

            for (pageIndex, page) in rawPages.enumerated() {
                let visibleSourceIdentifiers = Set(
                    page.placements.compactMap { placement in
                        descriptorByID[placement.itemID]?.block.sourceIdentifier
                    }
                )
                prepared.append(
                    PreparedPDFPage(
                        pageNumber: sectionStart + pageIndex,
                        pageCount: 0,
                        sectionNumber: sectionIndex + 1,
                        pageIndexInSection: pageIndex,
                        template: page.template,
                        placements: page.placements,
                        descriptorByID: descriptorByID,
                        headerFooter: section.headerFooter,
                        footnotes: resolvedFootnotes(
                            for: section,
                            sectionIndex: sectionIndex,
                            pageIndexInSection: pageIndex,
                            pageCountInSection: rawPages.count,
                            visibleSourceIdentifiers: visibleSourceIdentifiers,
                            documentSections: document.sections,
                            configuration: footnoteConfiguration
                        )
                    )
                )
            }

            nextPageNumber = (prepared.last?.pageNumber ?? (sectionStart - 1)) + 1
        }

        let totalPageCount = prepared.count
        return prepared.map { page in
            var updated = page
            updated.pageCount = totalPageCount
            return updated
        }
    }

    private func paginate(
        descriptors: [MeasuredExportBlock],
        templateProvider: any PageTemplateProvider,
        sectionIndex: Int
    ) async throws -> [PaginationPrimitive.ComputedPage] {
        let items = descriptors.map(\.item)
        return await MainActor.run {
            let engine = PaginationEngine(templateProvider: templateProvider)
            engine.paginate(items, section: sectionIndex)
            return engine.pages
        }
    }

    private func fallbackTemplate(includeMetadata: Bool) -> PageTemplate {
        let base = PageTemplate.letter
        return PageTemplate(
            size: base.size,
            margins: base.margins,
            headerHeight: includeMetadata ? 24 : 0,
            footerHeight: 22
        )
    }

    private func pageTemplate(from exportTemplate: ExportPageTemplate) -> PageTemplate {
        PageTemplate(
            size: exportTemplate.size,
            margins: SwiftUI.EdgeInsets(
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

    private func resolvedFootnotes(
        for section: ExportSection,
        sectionIndex: Int,
        pageIndexInSection: Int,
        pageCountInSection: Int,
        visibleSourceIdentifiers: Set<String>,
        documentSections: [ExportSection],
        configuration: ExportFootnoteConfiguration?
    ) -> [ExportFootnote] {
        guard let configuration else { return [] }

        switch configuration.placement {
        case .pageBottom:
            return section.footnotes.filter { visibleSourceIdentifiers.contains($0.anchorSourceIdentifier) }
        case .sectionEnd:
            guard pageIndexInSection == pageCountInSection - 1 else { return [] }
            return section.footnotes
        case .documentEnd:
            guard sectionIndex == documentSections.count - 1, pageIndexInSection == pageCountInSection - 1 else { return [] }
            return documentSections.flatMap(\.footnotes)
        }
    }

    private func pdfMetadata(for document: ExportableDocument) -> [String: Any] {
        var metadata: [String: Any] = [
            kCGPDFContextTitle as String: document.metadata.title,
        ]

        if let author = document.metadata.author {
            metadata[kCGPDFContextAuthor as String] = author
        }

        return metadata
    }

    private func drawPageChrome(
        context: CGContext,
        page: PreparedPDFPage,
        document: ExportableDocument,
        includeMetadata: Bool
    ) {
        if let headerFooter = resolvedHeaderFooter(for: page) {
            if let header = headerFooter.header, page.template.headerHeight > 0 {
                drawHeaderFooterRegion(
                    header,
                    in: CGRect(
                        x: page.template.margins.leading,
                        y: page.template.margins.top,
                        width: page.template.contentWidth,
                        height: page.template.headerHeight
                    ),
                    context: context,
                    page: page,
                    document: document
                )
            }

            if let footer = headerFooter.footer, page.template.footerHeight > 0 {
                drawHeaderFooterRegion(
                    footer,
                    in: CGRect(
                        x: page.template.margins.leading,
                        y: page.template.size.height - page.template.margins.bottom - page.template.footerHeight,
                        width: page.template.contentWidth,
                        height: page.template.footerHeight
                    ),
                    context: context,
                    page: page,
                    document: document
                )
            }

            return
        }

        if includeMetadata, page.template.headerHeight > 0 {
            drawText(
                attributedString: styledLine(
                    text: document.metadata.title,
                    fontSize: 11,
                    weight: .semibold
                ),
                in: CGRect(
                    x: page.template.margins.leading,
                    y: page.template.margins.top,
                    width: page.template.contentWidth,
                    height: page.template.headerHeight
                ),
                context: context
            )
        }

        drawText(
            attributedString: styledLine(
                text: "Page \(page.pageNumber) of \(page.pageCount)",
                fontSize: 10,
                weight: .regular,
                color: CGColor(gray: 0.35, alpha: 1)
            ),
            in: CGRect(
                x: page.template.margins.leading,
                y: page.template.size.height - page.template.margins.bottom - page.template.footerHeight,
                width: page.template.contentWidth,
                height: page.template.footerHeight
            ),
            context: context,
            alignment: .center
        )
    }

    private func drawHeaderFooterRegion(
        _ region: ExportHeaderFooter,
        in rect: CGRect,
        context: CGContext,
        page: PreparedPDFPage,
        document: ExportableDocument
    ) {
        let columnWidth = rect.width / 3

        drawText(
            attributedString: attributedText(
                for: resolvedTextContent(region.left, page: page, document: document),
                baseFontSize: 10,
                defaultColor: CGColor(gray: 0.35, alpha: 1)
            ),
            in: CGRect(x: rect.minX, y: rect.minY, width: columnWidth, height: rect.height),
            context: context
        )

        drawText(
            attributedString: attributedText(
                for: resolvedTextContent(region.center, page: page, document: document),
                baseFontSize: 10,
                defaultColor: CGColor(gray: 0.35, alpha: 1)
            ),
            in: CGRect(x: rect.minX + columnWidth, y: rect.minY, width: columnWidth, height: rect.height),
            context: context,
            alignment: .center
        )

        drawText(
            attributedString: attributedText(
                for: resolvedTextContent(region.right, page: page, document: document),
                baseFontSize: 10,
                defaultColor: CGColor(gray: 0.35, alpha: 1)
            ),
            in: CGRect(x: rect.minX + (columnWidth * 2), y: rect.minY, width: columnWidth, height: rect.height),
            context: context,
            alignment: .right
        )
    }

    private func resolvedHeaderFooter(for page: PreparedPDFPage) -> ExportHeaderFooterConfiguration? {
        guard var config = page.headerFooter else { return nil }

        if config.differentFirstPage, page.pageIndexInSection == 0 {
            config.header = nil
            config.footer = nil
        } else if config.differentOddEven, page.pageNumber.isMultiple(of: 2) {
            config.header = config.header.map { ExportHeaderFooter(left: $0.right, center: $0.center, right: $0.left) }
            config.footer = config.footer.map { ExportHeaderFooter(left: $0.right, center: $0.center, right: $0.left) }
        }

        return config
    }

    private func resolvedTextContent(
        _ content: ExportTextContent,
        page: PreparedPDFPage,
        document: ExportableDocument
    ) -> ExportTextContent {
        ExportTextContent(
            runs: content.runs.map { run in
                var updated = run
                updated.text = resolveInlineTokens(run.text, page: page, document: document)
                return updated
            }
        )
    }

    private func resolveInlineTokens(
        _ text: String,
        page: PreparedPDFPage,
        document: ExportableDocument
    ) -> String {
        let resolvedDate = (document.metadata.modifiedAt ?? document.metadata.createdAt ?? Date())
            .formatted(date: .abbreviated, time: .omitted)

        return [
            ("{{pageNumber}}", String(page.pageNumber)),
            ("{{pageCount}}", String(page.pageCount)),
            ("{{sectionNumber}}", String(page.sectionNumber)),
            ("{{date}}", resolvedDate),
            ("{{title}}", document.metadata.title),
            ("{{author}}", document.metadata.author ?? ""),
            ("{PAGE}", String(page.pageNumber)),
            ("{NUMPAGES}", String(page.pageCount)),
            ("{SECTION}", String(page.sectionNumber)),
            ("{DATE}", resolvedDate),
            ("{TITLE}", document.metadata.title),
            ("{AUTHOR}", document.metadata.author ?? ""),
        ].reduce(text) { partialResult, mapping in
            partialResult.replacingOccurrences(of: mapping.0, with: mapping.1)
        }
    }

    private func draw(
        descriptor: MeasuredExportBlock,
        placement: PagePlacement,
        in contentRect: CGRect,
        context: CGContext
    ) {
        let targetRect = CGRect(
            x: contentRect.minX + placement.frame.minX,
            y: contentRect.minY + placement.frame.minY,
            width: placement.frame.width,
            height: placement.frame.height
        )

        switch descriptor.block.content {
        case .divider:
            context.saveGState()
            context.setStrokeColor(CGColor(gray: 0.82, alpha: 1))
            context.setLineWidth(1)
            let y = targetRect.midY
            context.move(to: CGPoint(x: targetRect.minX, y: y))
            context.addLine(to: CGPoint(x: targetRect.maxX, y: y))
            context.strokePath()
            context.restoreGState()

        case .image:
            context.saveGState()
            context.setStrokeColor(CGColor(gray: 0.75, alpha: 1))
            context.setFillColor(CGColor(gray: 0.96, alpha: 1))
            context.fill(targetRect)
            context.stroke(targetRect)
            drawText(
                attributedString: styledLine(
                    text: descriptor.block.content.altTextOrPlaceholder,
                    fontSize: 12,
                    weight: .regular,
                    color: CGColor(gray: 0.35, alpha: 1)
                ),
                in: targetRect.insetBy(dx: 12, dy: 12),
                context: context,
                alignment: .center
            )
            context.restoreGState()

        default:
            guard let attributedText = descriptor.attributedText else { return }

            if descriptor.block.type == .blockQuote {
                context.saveGState()
                context.setFillColor(CGColor(gray: 0.82, alpha: 1))
                context.fill(CGRect(x: targetRect.minX, y: targetRect.minY, width: 3, height: targetRect.height))
                context.restoreGState()
            }

            let clipRect = targetRect.insetBy(dx: descriptor.horizontalInset, dy: 0)
            let contentOffset = placement.partialRange?.lowerBound ?? 0
            let contentRect = CGRect(
                x: clipRect.minX,
                y: clipRect.minY - contentOffset,
                width: clipRect.width,
                height: descriptor.item.height
            )

            context.saveGState()
            context.clip(to: clipRect)
            drawText(attributedString: attributedText, in: contentRect, context: context)
            context.restoreGState()
        }
    }

    private func measuredBlocks(
        for blocks: [ExportBlock],
        template: PageTemplate,
        footnotes: [ExportFootnote] = [],
        footnoteConfiguration: ExportFootnoteConfiguration? = nil
    ) -> [MeasuredExportBlock] {
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
        footnotes: [ExportFootnote] = [],
        footnoteConfiguration: ExportFootnoteConfiguration? = nil
    ) -> MeasuredExportBlock {
        let horizontalInset: CGFloat = block.type == .blockQuote ? 18 : 0
        let availableWidth = max(template.contentWidth - horizontalInset - 8, 72)
        let attributedText = attributedText(for: block)
        let anchoredFootnotes = footnotes.filter { $0.anchorSourceIdentifier == block.sourceIdentifier }
        let measuredHeight: CGFloat
        switch block.content {
        case .divider:
            measuredHeight = 24
        case .image:
            measuredHeight = 180
        default:
            let textHeight = attributedText.map { measure($0, width: availableWidth) } ?? 18
            measuredHeight = max(textHeight + 16, minimumHeight(for: block))
        }

        return MeasuredExportBlock(
            block: block,
            item: MeasuredItem(
                height: measuredHeight,
                canBreakInternally: canBreakInternally(block),
                keepWithNext: block.type == .heading,
                footnoteReservation: footnoteReservation(
                    for: anchoredFootnotes,
                    configuration: footnoteConfiguration
                )
            ),
            attributedText: attributedText,
            horizontalInset: horizontalInset
        )
    }

    private func footnoteReservation(
        for footnotes: [ExportFootnote],
        configuration: ExportFootnoteConfiguration?
    ) -> CGFloat {
        guard configuration?.placement == .pageBottom, !footnotes.isEmpty else { return 0 }

        return footnotes.reduce(CGFloat(12)) { partialResult, footnote in
            partialResult + estimatedFootnoteHeight(for: footnote.content)
        }
    }

    private func estimatedFootnoteHeight(for content: ExportTextContent) -> CGFloat {
        let lines = max(Int(ceil(Double(max(content.plainText.count, 1)) / 48.0)), 1)
        return CGFloat(lines) * 14 + 6
    }

    private func canBreakInternally(_ block: ExportBlock) -> Bool {
        switch block.content {
        case .text, .heading, .blockQuote, .codeBlock, .list, .table:
            true
        case .image, .divider:
            false
        }
    }

    private func minimumHeight(for block: ExportBlock) -> CGFloat {
        switch block.type {
        case .heading:
            32
        case .codeBlock:
            30
        default:
            18
        }
    }

    private func attributedText(for block: ExportBlock) -> NSAttributedString? {
        switch block.content {
        case let .text(content):
            return attributedText(for: content, baseFontSize: 12)
        case let .heading(content, level):
            let size = max(26 - CGFloat(max(level - 1, 0)) * 2.5, 14)
            return attributedText(for: content, baseFontSize: size, forceBold: true)
        case let .blockQuote(content):
            return attributedText(
                for: content,
                baseFontSize: 12,
                defaultColor: CGColor(gray: 0.25, alpha: 1)
            )
        case let .codeBlock(code, _):
            return styledLine(text: code, fontSize: 11, weight: .monospaced, color: CGColor(gray: 0.18, alpha: 1))
        case let .list(content, ordered, indentLevel):
            let prefix = ordered ? "1. " : "• "
            let indent = String(repeating: "  ", count: indentLevel)
            let rendered = ExportTextContent(
                runs: [ExportTextRun(text: indent + prefix)] + content.runs
            )
            return attributedText(for: rendered, baseFontSize: 12)
        case let .table(rows):
            let lines = rows.map { row in
                row.map(\.plainText).joined(separator: " | ")
            }.joined(separator: "\n")
            return styledLine(text: lines, fontSize: 11, weight: .monospaced, color: CGColor(gray: 0.18, alpha: 1))
        case .image, .divider:
            return nil
        }
    }

    private func attributedText(
        for content: ExportTextContent,
        baseFontSize: CGFloat,
        forceBold: Bool = false,
        defaultColor: CGColor = CGColor(gray: 0.1, alpha: 1)
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for run in content.runs {
            let size = baseFontSize
            let font = font(
                size: size,
                bold: forceBold || run.bold,
                italic: run.italic,
                code: run.code
            )
            var attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
                NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): defaultColor,
            ]

            if run.underline {
                attributes[.underlineStyle] = 1
            }
            if run.strikethrough {
                attributes[.strikethroughStyle] = 1
            }

            output.append(NSAttributedString(string: run.text, attributes: attributes))
        }
        return output
    }

    private func styledLine(
        text: String,
        fontSize: CGFloat,
        weight: PDFTextWeight,
        color: CGColor = CGColor(gray: 0.1, alpha: 1)
    ) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font(
                    size: fontSize,
                    bold: weight == .semibold,
                    italic: false,
                    code: weight == .monospaced
                ),
                NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): color,
            ]
        )
    }

    private func font(size: CGFloat, bold: Bool, italic: Bool, code: Bool) -> CTFont {
        let fontName: String
        if code {
            fontName = "Menlo-Regular"
        } else if bold && italic {
            fontName = "Helvetica-BoldOblique"
        } else if bold {
            fontName = "Helvetica-Bold"
        } else if italic {
            fontName = "Helvetica-Oblique"
        } else {
            fontName = "Helvetica"
        }

        return CTFontCreateWithName(fontName as CFString, size, nil)
    }

    private func measure(_ attributedString: NSAttributedString, width: CGFloat) -> CGFloat {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributedString.length),
            nil,
            CGSize(width: width, height: .greatestFiniteMagnitude),
            nil
        )
        return ceil(suggested.height)
    }

    private func drawText(
        attributedString: NSAttributedString,
        in rect: CGRect,
        context: CGContext,
        alignment: CTTextAlignment = .left
    ) {
        let attributed = NSMutableAttributedString(attributedString: attributedString)
        let drawRect: CGRect

        switch alignment {
        case .center:
            let line = CTLineCreateWithAttributedString(attributed)
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let centeredX = rect.minX + max((rect.width - lineWidth) / 2, 0)
            drawRect = CGRect(x: centeredX, y: rect.minY, width: max(lineWidth, rect.width), height: rect.height)
        case .right:
            let line = CTLineCreateWithAttributedString(attributed)
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            drawRect = CGRect(x: rect.maxX - lineWidth, y: rect.minY, width: max(lineWidth, rect.width), height: rect.height)
        default:
            drawRect = rect
        }

        let path = CGMutablePath()
        path.addRect(drawRect)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            path,
            nil
        )

        context.textMatrix = .identity
        CTFrameDraw(frame, context)
    }

    private func drawFootnotes(
        _ footnotes: [ExportFootnote],
        in contentRect: CGRect,
        context: CGContext,
        page: PreparedPDFPage,
        document: ExportableDocument
    ) {
        let heights = footnotes.map { estimatedFootnoteHeight(for: $0.content) }
        let totalHeight = heights.reduce(CGFloat(18), +)
        let startY = max(contentRect.maxY - totalHeight, contentRect.minY)

        context.saveGState()
        context.setStrokeColor(CGColor(gray: 0.75, alpha: 1))
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: contentRect.minX, y: startY))
        context.addLine(to: CGPoint(x: contentRect.minX + min(contentRect.width * 0.2, 72), y: startY))
        context.strokePath()
        context.restoreGState()

        var yOffset = startY + 6
        for (index, footnote) in footnotes.enumerated() {
            let number = footnoteNumber(
                page: page,
                localIndex: index,
                configuration: document.footnoteConfiguration
            )
            let rendered = ExportTextContent(
                runs: [ExportTextRun(text: "\(number). ")] + resolvedTextContent(footnote.content, page: page, document: document).runs
            )
            let height = heights[index]

            drawText(
                attributedString: attributedText(
                    for: rendered,
                    baseFontSize: 10,
                    defaultColor: CGColor(gray: 0.18, alpha: 1)
                ),
                in: CGRect(
                    x: contentRect.minX,
                    y: yOffset,
                    width: contentRect.width,
                    height: height
                ),
                context: context
            )

            yOffset += height
        }
    }

    private func footnoteNumber(
        page: PreparedPDFPage,
        localIndex: Int,
        configuration: ExportFootnoteConfiguration?
    ) -> Int {
        guard let configuration else { return localIndex + 1 }
        guard configuration.restartPerSection else { return localIndex + 1 }
        return localIndex + 1
    }
}

private struct PreparedPDFPage {
    var pageNumber: Int
    var pageCount: Int
    var sectionNumber: Int
    var pageIndexInSection: Int
    var template: PageTemplate
    var placements: [PagePlacement]
    var descriptorByID: [UUID: MeasuredExportBlock]
    var headerFooter: ExportHeaderFooterConfiguration?
    var footnotes: [ExportFootnote]

    static func fallback(for document: ExportableDocument, includeMetadata: Bool) -> PreparedPDFPage {
        let template = PageTemplate(
            size: PageTemplate.letter.size,
            margins: PageTemplate.letter.margins,
            headerHeight: includeMetadata ? 24 : 0,
            footerHeight: 22
        )
        return PreparedPDFPage(
            pageNumber: 1,
            pageCount: 1,
            sectionNumber: 1,
            pageIndexInSection: 0,
            template: template,
            placements: [],
            descriptorByID: [:],
            headerFooter: nil,
            footnotes: []
        )
    }
}

private struct MeasuredExportBlock {
    var block: ExportBlock
    var item: MeasuredItem
    var attributedText: NSAttributedString?
    var horizontalInset: CGFloat
}

private struct SectionTemplateProvider: PageTemplateProvider, Sendable {
    var template: PageTemplate
    var headerFooter: ExportHeaderFooterConfiguration?

    func template(forPage pageNumber: Int, isFirst: Bool, section: Int) -> PageTemplate {
        _ = pageNumber
        _ = section

        guard let headerFooter else { return template }
        guard headerFooter.differentFirstPage, isFirst else { return template }

        var adjusted = template
        adjusted.headerHeight = 0
        adjusted.footerHeight = 0
        return adjusted
    }
}

private enum PDFTextWeight {
    case regular
    case semibold
    case monospaced
}

private extension ExportBlockContent {
    var altTextOrPlaceholder: String {
        switch self {
        case let .image(_, _, altText):
            altText ?? "Image"
        default:
            ""
        }
    }
}
