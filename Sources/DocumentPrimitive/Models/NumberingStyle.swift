import Foundation

public enum NumberingStyle: String, Codable, Sendable {
    case arabic
    case roman
    case alpha
    case symbol

    public func render(number: Int) -> String {
        switch self {
        case .arabic:
            return String(number)
        case .roman:
            return ListNumberingStyle.upperRoman.render(number: number)
        case .alpha:
            return ListNumberingStyle.lowerAlpha.render(number: number)
        case .symbol:
            let symbols = ["*", "†", "‡", "§", "¶"]
            return symbols[(max(number, 1) - 1) % symbols.count]
        }
    }
}
