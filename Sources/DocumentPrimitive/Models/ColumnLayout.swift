import CoreGraphics
import Foundation

public struct ColumnLayout: Codable, Sendable, Equatable {
    public var columns: Int
    public var spacing: CGFloat
    public var equalWidth: Bool
    public var customWidths: [CGFloat]?

    public init(
        columns: Int = 1,
        spacing: CGFloat = 18,
        equalWidth: Bool = true,
        customWidths: [CGFloat]? = nil
    ) {
        self.columns = max(columns, 1)
        self.spacing = spacing
        self.equalWidth = equalWidth
        self.customWidths = customWidths
    }

    public func resolvedWidths(totalWidth: CGFloat) -> [CGFloat] {
        guard columns > 0 else { return [] }
        let totalSpacing = CGFloat(max(columns - 1, 0)) * spacing
        let availableWidth = max(totalWidth - totalSpacing, 0)

        if !equalWidth, let customWidths, customWidths.count == columns {
            return customWidths
        }

        let width = availableWidth / CGFloat(columns)
        return Array(repeating: width, count: columns)
    }

    public static var single: ColumnLayout {
        ColumnLayout(columns: 1, spacing: 0)
    }
}
