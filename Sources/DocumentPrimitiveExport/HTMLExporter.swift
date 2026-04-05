import DocumentPrimitive
import ExportKit
import Foundation
import UniformTypeIdentifiers

public struct HTMLExporter: DocumentExporter {
    public let formatID = "html"
    public let fileExtension = "html"
    public let utType = UTType.html
    private let fieldResolver = FieldCodeResolver()

    public init() {}

    public func export(_ document: ExportableDocument, options: ExportOptions) async throws -> Data {
        _ = options
        let body = renderBody(for: document)
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>\(escape(document.metadata.title))</title>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
        return Data(html.utf8)
    }

    private func renderBody(for document: ExportableDocument) -> String {
        guard !document.sections.isEmpty else {
            return document.blocks.map(render(block:)).joined(separator: "\n")
        }

        let sectionStartPages = sectionStartPages(for: document.sections)
        let totalPageCount = max(sectionStartPages.last ?? 1, 1)
        let configuration = document.footnoteConfiguration ?? ExportFootnoteConfiguration()
        var body: [String] = []
        var continuousFootnoteNumber = 1

        for (sectionIndex, section) in document.sections.enumerated() {
            let context = fieldContext(
                for: document,
                sectionIndex: sectionIndex,
                sectionStartPages: sectionStartPages,
                totalPageCount: totalPageCount
            )

            var parts: [String] = []

            if let header = render(headerFooter: section.headerFooter?.header, role: "header", context: context) {
                parts.append(header)
            }

            let blocks = section.blocks.map(render(block:)).joined(separator: "\n")
            if !blocks.isEmpty {
                parts.append(blocks)
            }

            if configuration.placement != .documentEnd,
               let footnotes = renderFootnotes(
                section.footnotes,
                title: "Footnotes",
                startingAt: configuration.restartPerSection ? 1 : continuousFootnoteNumber,
                sectionIndex: sectionIndex,
                configuration: configuration
               ) {
                parts.append(footnotes)
            }

            if let footer = render(headerFooter: section.headerFooter?.footer, role: "footer", context: context) {
                parts.append(footer)
            }

            continuousFootnoteNumber += section.footnotes.count

            body.append(
                """
                <section class="document-section" data-section-index="\(sectionIndex + 1)" data-columns="\(section.pageTemplate.columns)" data-start-page="\(sectionStartPages[sectionIndex])">
                \(parts.joined(separator: "\n"))
                </section>
                """
            )
        }

        if configuration.placement == .documentEnd,
           let documentFootnotes = renderDocumentFootnotes(
            sections: document.sections,
            configuration: configuration,
            continuousStart: 1
           ) {
            body.append(documentFootnotes)
        }

        return body.joined(separator: "\n")
    }

    private func render(block: ExportBlock) -> String {
        switch block.content {
        case let .text(content):
            return "<p>\(render(text: content))</p>"
        case let .heading(content, level):
            return "<h\(level)>\(render(text: content))</h\(level)>"
        case let .blockQuote(content):
            return "<blockquote>\(render(text: content))</blockquote>"
        case let .codeBlock(code, language):
            let languageClass = language.map { " class=\"language-\(escape($0))\"" } ?? ""
            return "<pre><code\(languageClass)>\(escape(code))</code></pre>"
        case let .list(content, ordered, _):
            let tag = ordered ? "ol" : "ul"
            return "<\(tag)><li>\(render(text: content))</li></\(tag)>"
        case let .table(rows, _, caption):
            let renderedRows = rows.map { row in
                "<tr>" + row.map { "<td>\(render(text: $0))</td>" }.joined() + "</tr>"
            }.joined()
            let renderedCaption = caption.map { "<caption>\(render(text: $0))</caption>" } ?? ""
            return "<table>\(renderedCaption)\(renderedRows)</table>"
        case let .image(data, url, altText, size):
            let source = imageSource(data: data, url: url)
            let srcAttribute = source.isEmpty ? "" : " src=\"\(escape(source))\""
            let sizeAttributes = size.map {
                " width=\"\(Int(max($0.width.rounded(), 1)))\" height=\"\(Int(max($0.height.rounded(), 1)))\""
            } ?? ""
            return "<img\(srcAttribute) alt=\"\(escape(altText ?? ""))\"\(sizeAttributes)>"
        case .divider:
            return "<hr>"
        }
    }

    private func render(text: ExportTextContent) -> String {
        text.runs.map(render(run:)).joined()
    }

    private func render(
        headerFooter: ExportHeaderFooter?,
        role: String,
        context: FieldResolutionContext
    ) -> String? {
        guard let headerFooter else { return nil }

        let left = renderResolved(text: headerFooter.left, context: context)
        let center = renderResolved(text: headerFooter.center, context: context)
        let right = renderResolved(text: headerFooter.right, context: context)

        guard !(left.isEmpty && center.isEmpty && right.isEmpty) else { return nil }

        return """
        <\(role) class="document-section-\(role)">
          <div class="\(role)-left">\(left)</div>
          <div class="\(role)-center">\(center)</div>
          <div class="\(role)-right">\(right)</div>
        </\(role)>
        """
    }

    private func renderFootnotes(
        _ footnotes: [ExportFootnote],
        title: String,
        startingAt startNumber: Int,
        sectionIndex: Int?,
        configuration: ExportFootnoteConfiguration
    ) -> String? {
        guard !footnotes.isEmpty else { return nil }

        let sectionAttribute = sectionIndex.map { " data-section-index=\"\($0 + 1)\"" } ?? ""
        let items = footnotes.enumerated().map { offset, footnote in
            let number = startNumber + offset
            let marker = configuration.numberingStyle.render(number: number)
            return """
            <li data-anchor-source="\(escape(footnote.anchorSourceIdentifier))" data-footnote-marker="\(escape(marker))"><span class="footnote-marker">\(escape(formattedFootnoteMarker(marker, style: configuration.numberingStyle)))</span>\(render(text: footnote.content))</li>
            """
        }.joined(separator: "\n")

        return """
        <aside class="document-footnotes"\(sectionAttribute)>
          <h2>\(escape(title))</h2>
          <ol style="list-style:none;padding-left:0;margin:0;">
        \(items)
          </ol>
        </aside>
        """
    }

    private func renderDocumentFootnotes(
        sections: [ExportSection],
        configuration: ExportFootnoteConfiguration,
        continuousStart: Int
    ) -> String? {
        if configuration.restartPerSection {
            let groups = sections.enumerated().compactMap { index, section in
                renderFootnotes(
                    section.footnotes,
                    title: "Section \(index + 1) Footnotes",
                    startingAt: 1,
                    sectionIndex: index,
                    configuration: configuration
                )
            }

            guard !groups.isEmpty else { return nil }
            return """
            <section class="document-endnotes">
            <h1>Document Footnotes</h1>
            \(groups.joined(separator: "\n"))
            </section>
            """
        }

        return renderFootnotes(
            sections.flatMap(\.footnotes),
            title: "Document Footnotes",
            startingAt: continuousStart,
            sectionIndex: nil,
            configuration: configuration
        )
    }

    private func renderResolved(text: ExportTextContent, context: FieldResolutionContext) -> String {
        render(text: resolved(text: text, context: context))
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
        var value = escape(run.text)
        if run.code { value = "<code>\(value)</code>" }
        if run.bold { value = "<strong>\(value)</strong>" }
        if run.italic { value = "<em>\(value)</em>" }
        if run.underline { value = "<u>\(value)</u>" }
        if run.strikethrough { value = "<s>\(value)</s>" }
        if let link = run.link {
            value = "<a href=\"\(escape(link.absoluteString))\">\(value)</a>"
        }
        return value
    }

    private func imageSource(data: Data?, url: URL?) -> String {
        if let url {
            return url.absoluteString
        }

        guard let data, let mimeType = mimeType(for: data) else { return "" }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func mimeType(for data: Data) -> String? {
        if data.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) {
            return "image/png"
        }
        if data.starts(with: Data([0xFF, 0xD8, 0xFF])) {
            return "image/jpeg"
        }
        if data.starts(with: Data("GIF8".utf8)) {
            return "image/gif"
        }
        return nil
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

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
