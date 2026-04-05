import DocumentPrimitive
import ExportKit
import Foundation
import UniformTypeIdentifiers

public struct MarkdownExporter: DocumentExporter {
    public let formatID = "markdown"
    public let fileExtension = "md"
    public let utType = UTType(exportedAs: "net.daringfireball.markdown")
    private let fieldResolver = FieldCodeResolver()

    public init() {}

    public func export(_ document: ExportableDocument, options: ExportOptions) async throws -> Data {
        _ = options
        let markdown = await renderDocument(document)
        return Data(markdown.utf8)
    }

    private func renderDocument(_ document: ExportableDocument) async -> String {
        guard !document.sections.isEmpty else {
            return document.blocks.map(render(block:)).joined(separator: "\n\n")
        }

        let metrics = await ExportPageMetricsResolver().resolve(document: document)
        let sectionStartPages = metrics.sectionStartPages
        let totalPageCount = metrics.totalPageCount
        let configuration = document.footnoteConfiguration ?? ExportFootnoteConfiguration()
        var renderedSections: [String] = []
        var continuousFootnoteNumber = 1

        for (sectionIndex, section) in document.sections.enumerated() {
            let baseContext = fieldContext(
                for: document,
                sectionIndex: sectionIndex,
                sectionStartPages: sectionStartPages,
                totalPageCount: totalPageCount
            )
            let firstContext = variantFieldContext(
                from: baseContext,
                configuration: section.headerFooter,
                sectionStartPage: sectionStartPages[sectionIndex],
                variant: .first
            )
            let primaryContext = variantFieldContext(
                from: baseContext,
                configuration: section.headerFooter,
                sectionStartPage: sectionStartPages[sectionIndex],
                variant: .primary
            )
            let evenContext = variantFieldContext(
                from: baseContext,
                configuration: section.headerFooter,
                sectionStartPage: sectionStartPages[sectionIndex],
                variant: .even
            )

            var sectionParts: [String] = [
                "<!-- section \(sectionIndex + 1) start-page: \(sectionStartPages[sectionIndex]) columns: \(section.pageTemplate.columns) -->",
            ]

            sectionParts.append(
                contentsOf: renderHeaderFooterConfiguration(
                    section.headerFooter,
                    label: "Header",
                    primaryContext: primaryContext,
                    firstContext: firstContext,
                    evenContext: evenContext
                )
            )

            let blocks = section.blocks.map(render(block:)).joined(separator: "\n\n")
            if !blocks.isEmpty {
                sectionParts.append(blocks)
            }

            if configuration.placement != .documentEnd,
               let footnotes = renderFootnotes(
                section.footnotes,
                title: "Footnotes",
                startingAt: configuration.restartPerSection ? 1 : continuousFootnoteNumber,
                configuration: configuration
               ) {
                sectionParts.append(footnotes)
            }

            sectionParts.append(
                contentsOf: renderHeaderFooterConfiguration(
                    section.headerFooter,
                    label: "Footer",
                    primaryContext: primaryContext,
                    firstContext: firstContext,
                    evenContext: evenContext
                )
            )

            continuousFootnoteNumber += section.footnotes.count
            renderedSections.append(sectionParts.joined(separator: "\n\n"))
        }

        if configuration.placement == .documentEnd,
           let documentFootnotes = renderDocumentFootnotes(sections: document.sections, configuration: configuration) {
            renderedSections.append(documentFootnotes)
        }

        return renderedSections.joined(separator: "\n\n---\n\n")
    }

    private func render(block: ExportBlock) -> String {
        switch block.content {
        case let .text(content):
            return render(text: content)
        case let .heading(content, level):
            return "\(String(repeating: "#", count: max(level, 1))) \(render(text: content))"
        case let .blockQuote(content):
            return render(text: content)
                .split(separator: "\n")
                .map { "> \($0)" }
                .joined(separator: "\n")
        case let .codeBlock(code, language):
            return "```\(language ?? "")\n\(code)\n```"
        case let .list(content, ordered, indentLevel):
            let prefix = ordered ? "1. " : "- "
            let indent = String(repeating: "  ", count: indentLevel)
            return "\(indent)\(prefix)\(render(text: content))"
        case let .table(rows, _, caption):
            var lines: [String] = []
            if let caption, !caption.plainText.isEmpty {
                lines.append("_\(render(text: caption))_")
            }

            guard let firstRow = rows.first else {
                return lines.joined(separator: "\n\n")
            }

            lines.append("| " + firstRow.map { render(text: $0) }.joined(separator: " | ") + " |")
            lines.append("| " + firstRow.map { _ in "---" }.joined(separator: " | ") + " |")
            lines.append(
                contentsOf: rows.dropFirst().map { row in
                    "| " + row.map { render(text: $0) }.joined(separator: " | ") + " |"
                }
            )
            return lines.joined(separator: "\n")
        case let .image(_, url, altText, _):
            return "![\(altText ?? "")](\(url?.absoluteString ?? ""))"
        case .divider:
            return "---"
        }
    }

    private func render(text: ExportTextContent) -> String {
        text.runs.map(render(run:)).joined()
    }

    private func render(
        headerFooter: ExportHeaderFooter?,
        label: String,
        context: FieldResolutionContext
    ) -> String? {
        guard let headerFooter else { return nil }

        let columns = [
            render(text: resolved(text: headerFooter.left, context: context)),
            render(text: resolved(text: headerFooter.center, context: context)),
            render(text: resolved(text: headerFooter.right, context: context)),
        ].filter { !$0.isEmpty }

        guard !columns.isEmpty else { return nil }
        return "_\(label):_ " + columns.joined(separator: " | ")
    }

    private func renderHeaderFooterConfiguration(
        _ configuration: ExportHeaderFooterConfiguration?,
        label: String,
        primaryContext: FieldResolutionContext,
        firstContext: FieldResolutionContext,
        evenContext: FieldResolutionContext
    ) -> [String] {
        guard let configuration else { return [] }

        let firstHeaderFooter: ExportHeaderFooter?
        let primaryHeaderFooter: ExportHeaderFooter?
        let evenHeaderFooter: ExportHeaderFooter?
        switch label {
        case "Header":
            firstHeaderFooter = configuration.firstHeader
            primaryHeaderFooter = configuration.header
            evenHeaderFooter = configuration.evenHeader
        case "Footer":
            firstHeaderFooter = configuration.firstFooter
            primaryHeaderFooter = configuration.footer
            evenHeaderFooter = configuration.evenFooter
        default:
            firstHeaderFooter = nil
            primaryHeaderFooter = nil
            evenHeaderFooter = nil
        }

        var rendered: [String] = []
        if configuration.differentFirstPage,
           let first = render(headerFooter: firstHeaderFooter, label: "First \(label)", context: firstContext) {
            rendered.append(first)
        }

        let primaryLabel = configuration.differentOddEven ? "Odd \(label)" : label
        if let primary = render(headerFooter: primaryHeaderFooter, label: primaryLabel, context: primaryContext) {
            rendered.append(primary)
        }

        if configuration.differentOddEven,
           let even = render(headerFooter: evenHeaderFooter, label: "Even \(label)", context: evenContext) {
            rendered.append(even)
        }

        return rendered
    }

    private func renderFootnotes(
        _ footnotes: [ExportFootnote],
        title: String,
        startingAt startNumber: Int,
        configuration: ExportFootnoteConfiguration
    ) -> String? {
        guard !footnotes.isEmpty else { return nil }

        let items = footnotes.enumerated().map { offset, footnote in
            let number = startNumber + offset
            let marker = configuration.numberingStyle.render(number: number)
            return "\(formattedFootnoteMarker(marker, style: configuration.numberingStyle))\(render(text: footnote.content))"
        }.joined(separator: "\n")

        return """
        #### \(title)

        \(items)
        """
    }

    private func renderDocumentFootnotes(
        sections: [ExportSection],
        configuration: ExportFootnoteConfiguration
    ) -> String? {
        if configuration.restartPerSection {
            let groups: [String] = sections.enumerated().compactMap { entry in
                let (index, section) = entry
                guard let footnotes = renderFootnotes(
                    section.footnotes,
                    title: "Section \(index + 1) Footnotes",
                    startingAt: 1,
                    configuration: configuration
                ) else {
                    return nil
                }
                return footnotes
            }

            guard !groups.isEmpty else { return nil }
            return (["## Document Footnotes"] + groups).joined(separator: "\n\n")
        }

        return renderFootnotes(
            sections.flatMap(\.footnotes),
            title: "Document Footnotes",
            startingAt: 1,
            configuration: configuration
        )
    }

    private func formattedFootnoteMarker(
        _ marker: String,
        style: ExportNumberingStyle
    ) -> String {
        if style == .symbol {
            return "\(marker) "
        }
        return "\(marker). "
    }

    private func resolved(text: ExportTextContent, context: FieldResolutionContext) -> ExportTextContent {
        ExportTextContent(
            runs: text.runs.map { run in
                var updated = run
                updated.text = fieldResolver.resolveInlineTokens(in: updated.text, context: context)
                return updated
            }
        )
    }

    private func fieldContext(
        for document: ExportableDocument,
        sectionIndex: Int,
        sectionStartPages: [Int],
        totalPageCount: Int
    ) -> FieldResolutionContext {
        FieldResolutionContext(
            pageNumber: sectionStartPages[sectionIndex],
            pageCount: totalPageCount,
            sectionNumber: sectionIndex + 1,
            date: document.metadata.modifiedAt ?? document.metadata.createdAt ?? Date(),
            title: document.metadata.title,
            author: document.metadata.author
        )
    }

    private func variantFieldContext(
        from context: FieldResolutionContext,
        configuration: ExportHeaderFooterConfiguration?,
        sectionStartPage: Int,
        variant: ExportHeaderFooterPageVariant
    ) -> FieldResolutionContext {
        let pageNumber = representativePageNumber(
            configuration: configuration,
            sectionStartPage: sectionStartPage,
            variant: variant
        )
        return FieldResolutionContext(
            pageNumber: pageNumber,
            pageCount: context.pageCount,
            sectionNumber: context.sectionNumber,
            date: context.date,
            title: context.title,
            author: context.author
        )
    }

    private func representativePageNumber(
        configuration: ExportHeaderFooterConfiguration?,
        sectionStartPage: Int,
        variant: ExportHeaderFooterPageVariant
    ) -> Int {
        let startPage = max(sectionStartPage, 1)
        guard let configuration else { return startPage }

        for candidate in startPage..<(startPage + 6) {
            let pageIndex = candidate - startPage
            let resolvedVariant: ExportHeaderFooterPageVariant
            if configuration.differentFirstPage, pageIndex == 0 {
                resolvedVariant = .first
            } else if configuration.differentOddEven, candidate.isMultiple(of: 2) {
                resolvedVariant = .even
            } else {
                resolvedVariant = .primary
            }

            if resolvedVariant == variant {
                return candidate
            }
        }

        return startPage
    }

    private func render(run: ExportTextRun) -> String {
        var value = run.text
        if run.code { value = "`\(value)`" }
        if run.bold { value = "**\(value)**" }
        if run.italic { value = "_\(value)_" }
        if let link = run.link {
            value = "[\(value)](\(link.absoluteString))"
        }
        return value
    }
}

private enum ExportHeaderFooterPageVariant {
    case first
    case primary
    case even
}
