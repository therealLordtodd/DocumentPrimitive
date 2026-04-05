import CoreGraphics
import Foundation

public struct ListDefinitionID: Sendable, Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

public enum ListNumberingStyle: Codable, Sendable, Equatable {
    case bullet
    case decimal
    case lowerAlpha
    case upperAlpha
    case lowerRoman
    case upperRoman
    case custom(String)

    public func render(number: Int) -> String {
        switch self {
        case .bullet:
            "•"
        case .decimal:
            String(number)
        case .lowerAlpha:
            alpha(number, uppercase: false)
        case .upperAlpha:
            alpha(number, uppercase: true)
        case .lowerRoman:
            roman(number).lowercased()
        case .upperRoman:
            roman(number)
        case let .custom(value):
            value.replacingOccurrences(of: "%n", with: String(number))
        }
    }

    private func alpha(_ number: Int, uppercase: Bool) -> String {
        guard number > 0 else { return uppercase ? "A" : "a" }
        let scalar = UnicodeScalar(((number - 1) % 26) + 65)!
        let string = String(Character(scalar))
        return uppercase ? string : string.lowercased()
    }

    private func roman(_ number: Int) -> String {
        guard number > 0 else { return "I" }
        let values: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
        ]
        var remainder = number
        var result = ""
        for (value, symbol) in values {
            while remainder >= value {
                result += symbol
                remainder -= value
            }
        }
        return result
    }
}

public struct ListLevelFormat: Codable, Sendable, Equatable {
    public var style: ListNumberingStyle
    public var format: String
    public var indent: CGFloat
    public var hangingIndent: CGFloat
    public var startAt: Int

    public init(
        style: ListNumberingStyle = .decimal,
        format: String = "%1.",
        indent: CGFloat = 18,
        hangingIndent: CGFloat = 9,
        startAt: Int = 1
    ) {
        self.style = style
        self.format = format
        self.indent = indent
        self.hangingIndent = hangingIndent
        self.startAt = startAt
    }
}

public struct ListDefinition: Identifiable, Codable, Sendable, Equatable {
    public let id: ListDefinitionID
    public var levels: [ListLevelFormat]

    public init(
        id: ListDefinitionID = ListDefinitionID(UUID().uuidString),
        levels: [ListLevelFormat]
    ) {
        self.id = id
        self.levels = levels
    }

    public func render(level: Int, counters: [Int]) -> String {
        guard levels.indices.contains(level) else { return "" }
        var result = levels[level].format

        for index in 0...level {
            let format = levels[index]
            let number = counters.indices.contains(index) ? counters[index] : format.startAt
            result = result.replacingOccurrences(
                of: "%\(index + 1)",
                with: format.style.render(number: number)
            )
        }

        return result
    }
}
