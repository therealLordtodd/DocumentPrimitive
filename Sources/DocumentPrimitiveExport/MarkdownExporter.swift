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
        let markdown = renderDocument(document)
        return Data(markdown.utf8)
    }

    private func renderDocument(_ document: ExportableDocument) -> String {
        guard !document.sections.isEmpty else {
            return document.blocks.map(render(block:)).joined(separator: "\n\n")
        }

        let sectionStartPages = sectionStartPages(for: document.sections)
        let totalPageCount = max(sectionStartPages.last ?? 1, 1)
        let configuration = document.footnoteConfiguration ?? ExportFootnoteConfiguration()
        var renderedSections: [String] = []
        var continuousFootnoteNumber = 1

        for (sectionIndex, section) in document.sections.enumerated() {
            let context = fieldContext(
                for: document,
                sectionIndex: sectionIndex,
                sectionStartPages: sectionStartPages,
                totalPageCount: totalPageCount
            )

            var sectionParts: [String] = [
                "<!-- section \(sectionIndex + 1) start-page: \(sectionStartPages[sectionIndex]) columns: \(section.pageTemplate.columns) -->",
            ]

            if let header = render(headerFooter: section.headerFooter?.header, label: "Header", context: context) {
                sectionParts.append(header)
            }

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

            if let footer = render(headerFooter: section.headerFooter?.footer, label: "Footer", context: context) {
                sectionParts.append(footer)
            }

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

    private func sectionStartPages(for sections: [ExportSection]) -> [Int] {
        var pages: [Int] = []
        var nextPage = 1

        for section in sections {
            let startPage = max(section.startPageNumber ?? nextPage, 1)
            pages.append(startPage)
            nextPage = startPage + 1
        }

        return pages
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
