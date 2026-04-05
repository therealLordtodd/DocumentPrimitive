import DocumentPrimitive
import ExportKit
import Foundation
import UniformTypeIdentifiers

public struct MarkdownExporter: DocumentExporter {
    public let formatID = "markdown"
    public let fileExtension = "md"
    public let utType = UTType(exportedAs: "net.daringfireball.markdown")

    public init() {}

    public func export(_ document: ExportableDocument, options: ExportOptions) async throws -> Data {
        _ = options
        let markdown = document.blocks.map(render(block:)).joined(separator: "\n\n")
        return Data(markdown.utf8)
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
        case let .table(rows):
            let body = rows.map { row in
                "| " + row.map { render(text: $0) }.joined(separator: " | ") + " |"
            }
            return body.joined(separator: "\n")
        case let .image(_, url, altText):
            return "![\(altText ?? "")](\(url?.absoluteString ?? ""))"
        case .divider:
            return "---"
        }
    }

    private func render(text: ExportTextContent) -> String {
        text.runs.map(render(run:)).joined()
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
