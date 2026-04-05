import CoreGraphics
import CoreText
import ExportKit
import Foundation
import PaginationPrimitive
import UniformTypeIdentifiers

public struct PDFExporter: DocumentExporter {
    public let formatID = "pdf"
    public let fileExtension = "pdf"
    public let utType = UTType.pdf

    public init() {}

    public func export(_ document: ExportableDocument, options: ExportOptions) async throws -> Data {
        let template = exportTemplate(includeMetadata: options.includeMetadata)
        let descriptors = measuredBlocks(for: document, template: template)
        let items = descriptors.map(\.item)
        let pages = await MainActor.run { () -> [PaginationPrimitive.ComputedPage] in
            let engine = PaginationEngine(template: template)
            engine.paginate(items)
            return engine.pages
        }

        let descriptorByID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.item.id, $0) })
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: template.size)

        guard
            let consumer = CGDataConsumer(data: data),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetadata(for: document) as CFDictionary)
        else {
            return Data()
        }

        let renderedPages = pages.isEmpty ? [PaginationPrimitive.ComputedPage(pageNumber: 1, template: template)] : pages
        for page in renderedPages {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(origin: .zero, size: template.size))

            context.saveGState()
            context.translateBy(x: 0, y: template.size.height)
            context.scaleBy(x: 1, y: -1)

            drawPageChrome(
                context: context,
                template: template,
                pageNumber: page.pageNumber,
                pageCount: renderedPages.count,
                document: document,
                includeMetadata: options.includeMetadata
            )

            let contentRect = CGRect(
                x: template.margins.leading,
                y: template.margins.top + template.headerHeight,
                width: template.contentWidth,
                height: template.contentHeight
            )

            for placement in page.placements {
                guard let descriptor = descriptorByID[placement.itemID] else { continue }
                draw(
                    descriptor: descriptor,
                    placement: placement,
                    in: contentRect,
                    context: context
                )
            }

            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()
        return data as Data
    }

    private func exportTemplate(includeMetadata: Bool) -> PageTemplate {
        let base = PageTemplate.letter
        return PageTemplate(
            size: base.size,
            margins: base.margins,
            headerHeight: includeMetadata ? 24 : 0,
            footerHeight: 22
        )
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
        template: PageTemplate,
        pageNumber: Int,
        pageCount: Int,
        document: ExportableDocument,
        includeMetadata: Bool
    ) {
        if includeMetadata, template.headerHeight > 0 {
            drawText(
                attributedString: styledLine(
                    text: document.metadata.title,
                    fontSize: 11,
                    weight: .semibold
                ),
                in: CGRect(
                    x: template.margins.leading,
                    y: template.margins.top,
                    width: template.contentWidth,
                    height: template.headerHeight
                ),
                context: context
            )
        }

        drawText(
            attributedString: styledLine(
                text: "Page \(pageNumber) of \(pageCount)",
                fontSize: 10,
                weight: .regular,
                color: CGColor(gray: 0.35, alpha: 1)
            ),
            in: CGRect(
                x: template.margins.leading,
                y: template.size.height - template.margins.bottom - template.footerHeight,
                width: template.contentWidth,
                height: template.footerHeight
            ),
            context: context,
            alignment: .center
        )
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
        for document: ExportableDocument,
        template: PageTemplate
    ) -> [MeasuredExportBlock] {
        document.blocks.map { block in
            measuredBlock(for: block, template: template)
        }
    }

    private func measuredBlock(
        for block: ExportBlock,
        template: PageTemplate
    ) -> MeasuredExportBlock {
        let horizontalInset: CGFloat = block.type == .blockQuote ? 18 : 0
        let availableWidth = max(template.contentWidth - horizontalInset - 8, 72)
        let attributedText = attributedText(for: block)
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
                keepWithNext: block.type == .heading
            ),
            attributedText: attributedText,
            horizontalInset: horizontalInset
        )
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
        if alignment == .center {
            let line = CTLineCreateWithAttributedString(attributed)
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let centeredX = rect.minX + max((rect.width - lineWidth) / 2, 0)
            drawRect = CGRect(x: centeredX, y: rect.minY, width: max(lineWidth, rect.width), height: rect.height)
        } else {
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
}

private struct MeasuredExportBlock {
    var block: ExportBlock
    var item: MeasuredItem
    var attributedText: NSAttributedString?
    var horizontalInset: CGFloat
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
