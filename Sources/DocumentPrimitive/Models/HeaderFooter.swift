import Foundation
import RichTextPrimitive

public struct HeaderFooterConfig: Codable, Sendable, Equatable {
    public var firstHeader: HeaderFooter?
    public var firstFooter: HeaderFooter?
    public var header: HeaderFooter?
    public var footer: HeaderFooter?
    public var evenHeader: HeaderFooter?
    public var evenFooter: HeaderFooter?
    public var differentFirstPage: Bool
    public var differentOddEven: Bool

    public init(
        firstHeader: HeaderFooter? = nil,
        firstFooter: HeaderFooter? = nil,
        header: HeaderFooter? = nil,
        footer: HeaderFooter? = nil,
        evenHeader: HeaderFooter? = nil,
        evenFooter: HeaderFooter? = nil,
        differentFirstPage: Bool = false,
        differentOddEven: Bool = false
    ) {
        self.firstHeader = firstHeader
        self.firstFooter = firstFooter
        self.header = header
        self.footer = footer
        self.evenHeader = differentOddEven ? (evenHeader ?? header) : evenHeader
        self.evenFooter = differentOddEven ? (evenFooter ?? footer) : evenFooter
        self.differentFirstPage = differentFirstPage
        self.differentOddEven = differentOddEven
    }

    public var hasAnyHeaderContent: Bool {
        firstHeader != nil || header != nil || evenHeader != nil
    }

    public var hasAnyFooterContent: Bool {
        firstFooter != nil || footer != nil || evenFooter != nil
    }

    public func resolvedHeaderFooter(
        pageNumber: Int,
        pageIndexInSection: Int
    ) -> (header: HeaderFooter?, footer: HeaderFooter?) {
        if differentFirstPage, pageIndexInSection == 0 {
            return (firstHeader, firstFooter)
        }

        if differentOddEven, pageNumber.isMultiple(of: 2) {
            return (evenHeader, evenFooter)
        }

        return (header, footer)
    }

    enum CodingKeys: String, CodingKey {
        case firstHeader
        case firstFooter
        case header
        case footer
        case evenHeader
        case evenFooter
        case differentFirstPage
        case differentOddEven
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            firstHeader: try container.decodeIfPresent(HeaderFooter.self, forKey: .firstHeader),
            firstFooter: try container.decodeIfPresent(HeaderFooter.self, forKey: .firstFooter),
            header: try container.decodeIfPresent(HeaderFooter.self, forKey: .header),
            footer: try container.decodeIfPresent(HeaderFooter.self, forKey: .footer),
            evenHeader: try container.decodeIfPresent(HeaderFooter.self, forKey: .evenHeader),
            evenFooter: try container.decodeIfPresent(HeaderFooter.self, forKey: .evenFooter),
            differentFirstPage: try container.decodeIfPresent(Bool.self, forKey: .differentFirstPage) ?? false,
            differentOddEven: try container.decodeIfPresent(Bool.self, forKey: .differentOddEven) ?? false
        )
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
