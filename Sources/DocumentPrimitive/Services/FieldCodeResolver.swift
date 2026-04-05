import Foundation
import RichTextPrimitive

public struct FieldResolutionContext: Sendable, Equatable {
    public var pageNumber: Int
    public var pageCount: Int
    public var sectionNumber: Int
    public var date: Date
    public var title: String
    public var author: String?

    public init(
        pageNumber: Int = 1,
        pageCount: Int = 1,
        sectionNumber: Int = 1,
        date: Date = Date(),
        title: String,
        author: String? = nil
    ) {
        self.pageNumber = pageNumber
        self.pageCount = pageCount
        self.sectionNumber = sectionNumber
        self.date = date
        self.title = title
        self.author = author
    }
}

public struct FieldCodeResolver: Sendable {
    public init() {}

    public func resolve(_ code: FieldCode, context: FieldResolutionContext) -> String {
        switch code {
        case .pageNumber:
            String(context.pageNumber)
        case .pageCount:
            String(context.pageCount)
        case .sectionNumber:
            String(context.sectionNumber)
        case .date:
            context.date.formatted(date: .abbreviated, time: .omitted)
        case .title:
            context.title
        case .author:
            context.author ?? ""
        }
    }

    public func resolveInlineTokens(in text: String, context: FieldResolutionContext) -> String {
        tokenMappings(for: context).reduce(text) { partialResult, mapping in
            partialResult.replacingOccurrences(of: mapping.token, with: mapping.value)
        }
    }

    public func resolve(runs: [TextRun], context: FieldResolutionContext) -> [TextRun] {
        runs.map { run in
            var updated = run
            updated.text = resolveInlineTokens(in: run.text, context: context)
            return updated
        }
    }

    private func tokenMappings(for context: FieldResolutionContext) -> [(token: String, value: String)] {
        [
            ("{{pageNumber}}", resolve(.pageNumber, context: context)),
            ("{{pageCount}}", resolve(.pageCount, context: context)),
            ("{{sectionNumber}}", resolve(.sectionNumber, context: context)),
            ("{{date}}", resolve(.date, context: context)),
            ("{{title}}", resolve(.title, context: context)),
            ("{{author}}", resolve(.author, context: context)),
            ("{PAGE}", resolve(.pageNumber, context: context)),
            ("{NUMPAGES}", resolve(.pageCount, context: context)),
            ("{SECTION}", resolve(.sectionNumber, context: context)),
            ("{DATE}", resolve(.date, context: context)),
            ("{TITLE}", resolve(.title, context: context)),
            ("{AUTHOR}", resolve(.author, context: context)),
        ]
    }
}
