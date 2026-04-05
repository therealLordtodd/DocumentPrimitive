import CoreGraphics
import Foundation
import PaginationPrimitive
import SwiftUI

public enum PageOrientation: String, Codable, Sendable {
    case portrait
    case landscape
}

public enum PageSize: Codable, Sendable, Equatable {
    case letter
    case a4
    case legal
    case custom(width: CGFloat, height: CGFloat)

    public var size: CGSize {
        switch self {
        case .letter:
            CGSize(width: 612, height: 792)
        case .a4:
            CGSize(width: 595.28, height: 841.89)
        case .legal:
            CGSize(width: 612, height: 1008)
        case let .custom(width, height):
            CGSize(width: width, height: height)
        }
    }
}

public struct PageSetup: Codable, Sendable, Equatable {
    public var pageSize: PageSize
    public var margins: EdgeInsets
    public var orientation: PageOrientation

    public init(
        pageSize: PageSize = .letter,
        margins: EdgeInsets = EdgeInsets(top: 72, leading: 72, bottom: 72, trailing: 72),
        orientation: PageOrientation = .portrait
    ) {
        self.pageSize = pageSize
        self.margins = margins
        self.orientation = orientation
    }

    public var canvasSize: CGSize {
        let base = pageSize.size
        guard orientation == .landscape else { return base }
        return CGSize(width: base.height, height: base.width)
    }

    public func pageTemplate(
        columns: Int = 1,
        columnSpacing: CGFloat = 18,
        headerHeight: CGFloat = 0,
        footerHeight: CGFloat = 0
    ) -> PageTemplate {
        PageTemplate(
            size: canvasSize,
            margins: margins,
            columns: columns,
            columnSpacing: columnSpacing,
            headerHeight: headerHeight,
            footerHeight: footerHeight
        )
    }

    public static var letter: PageSetup {
        PageSetup(pageSize: .letter)
    }

    public static var a4: PageSetup {
        PageSetup(pageSize: .a4)
    }
}
