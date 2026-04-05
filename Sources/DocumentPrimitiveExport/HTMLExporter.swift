import DocumentPrimitive
import ExportKit
import Foundation
import UniformTypeIdentifiers

public struct HTMLExporter: DocumentExporter {
    public let formatID = "html"
    public let fileExtension = "html"
    public let utType = UTType.html

    public init() {}

    public func export(_ document: ExportableDocument, options: ExportOptions) async throws -> Data {
        _ = options
        let body = document.blocks.map(render(block:)).joined(separator: "\n")
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
        case let .table(rows):
            let renderedRows = rows.map { row in
                "<tr>" + row.map { "<td>\(render(text: $0))</td>" }.joined() + "</tr>"
            }.joined()
            return "<table>\(renderedRows)</table>"
        case let .image(_, url, altText):
            let source = url?.absoluteString ?? ""
            return "<img src=\"\(escape(source))\" alt=\"\(escape(altText ?? ""))\">"
        case .divider:
            return "<hr>"
        }
    }

    private func render(text: ExportTextContent) -> String {
        text.runs.map(render(run:)).joined()
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

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
