import Foundation
import RichTextPrimitive

public struct HeaderFooterConfig: Codable, Sendable, Equatable {
    public var header: HeaderFooter?
    public var footer: HeaderFooter?
    public var differentFirstPage: Bool
    public var differentOddEven: Bool

    public init(
        header: HeaderFooter? = nil,
        footer: HeaderFooter? = nil,
        differentFirstPage: Bool = false,
        differentOddEven: Bool = false
    ) {
        self.header = header
        self.footer = footer
        self.differentFirstPage = differentFirstPage
        self.differentOddEven = differentOddEven
    }
}

public struct HeaderFooter: Codable, Sendable, Equatable {
    public var left: [TextRun]
    public var center: [TextRun]
    public var right: [TextRun]

    public init(
        left: [TextRun] = [],
        center: [TextRun] = [],
        right: [TextRun] = []
    ) {
        self.left = left
        self.center = center
        self.right = right
    }
}
