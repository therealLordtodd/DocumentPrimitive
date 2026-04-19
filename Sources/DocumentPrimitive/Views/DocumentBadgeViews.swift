import BadgePrimitive
import SwiftUI

enum DocumentBadgeStyles {
    static func metadata(theme: DocumentTheme) -> BadgeStyle {
        BadgeStyle(
            color: theme.colors.secondary.opacity(0.14),
            textColor: theme.colors.secondary,
            size: .medium,
            shape: .capsule,
            animation: .none
        )
    }

    static func page(theme: DocumentTheme) -> BadgeStyle {
        BadgeStyle(
            color: theme.colors.secondary.opacity(0.16),
            textColor: theme.colors.secondary,
            size: .medium,
            shape: .capsule,
            animation: .none
        )
    }

    static func review(tint: Color) -> BadgeStyle {
        BadgeStyle(
            color: tint.opacity(0.14),
            textColor: tint,
            size: .medium,
            shape: .capsule,
            animation: .none
        )
    }
}

struct DocumentMetadataBadge: View {
    let text: String
    @Environment(\.documentTheme) private var theme

    var body: some View {
        BadgeView(.text(text), style: DocumentBadgeStyles.metadata(theme: theme))
    }
}

struct DocumentPageBadge: View {
    let pageNumber: Int
    @Environment(\.documentTheme) private var theme

    var body: some View {
        BadgeView(.text("p.\(pageNumber)"), style: DocumentBadgeStyles.page(theme: theme))
    }
}

struct DocumentReviewCountBadge: View {
    let systemImage: String
    let label: String
    let tint: Color

    var body: some View {
        BadgeView(
            icon: Image(systemName: systemImage),
            text: label,
            style: DocumentBadgeStyles.review(tint: tint),
            accessibilityLabel: label
        )
    }
}

struct DocumentTintedBadge: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        BadgeView(
            icon: Image(systemName: systemImage),
            text: text,
            style: DocumentBadgeStyles.review(tint: tint),
            accessibilityLabel: text
        )
    }
}
