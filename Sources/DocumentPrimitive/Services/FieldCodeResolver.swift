import Foundation

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
}
