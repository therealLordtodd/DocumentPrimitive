import ColorPickerPrimitive
import Foundation
import RichTextPrimitive
import TrackChangesPrimitive

struct TrackedChangeSummaryResolver {
    func summary(for change: TrackedChange, context: TrackedChangeContext?) -> String {
        switch change.type {
        case let .insertion(text):
            let preview = trimmedPreview(for: text, fallback: "Insertion")
            if case let .insert(blocks, _) = context?.operation {
                return structuralSummary(
                    count: blocks.count,
                    singular: "Inserted block",
                    plural: "Inserted blocks",
                    preview: preview == "Insertion" ? "" : preview
                )
            }
            return preview == "Insertion" ? preview : "Insert: \(String(preview.prefix(24)))"
        case let .deletion(text):
            let preview = trimmedPreview(for: text, fallback: "Deletion")
            if case let .delete(blocks, _) = context?.operation {
                return structuralSummary(
                    count: blocks.count,
                    singular: "Deleted block",
                    plural: "Deleted blocks",
                    preview: preview == "Deletion" ? "" : preview
                )
            }
            return preview == "Deletion" ? preview : "Delete: \(String(preview.prefix(24)))"
        case .formatChange:
            if let context,
               case let .replace(before, after) = context.operation,
               let detail = formatSummary(from: before, to: after) {
                return detail
            }
            return "Formatting change"
        }
    }

    private func formatSummary(from before: Block, to after: Block) -> String? {
        if before.type != after.type {
            return "Block type: \(readableBlockType(before.type)) -> \(readableBlockType(after.type))"
        }

        switch (before.content, after.content) {
        case let (.heading(_, beforeLevel), .heading(_, afterLevel)) where beforeLevel != afterLevel:
            return "Heading level: \(beforeLevel) -> \(afterLevel)"
        case let (.list(_, beforeStyle, beforeIndent), .list(_, afterStyle, afterIndent)):
            if beforeStyle != afterStyle {
                return "List style: \(readableListStyle(beforeStyle)) -> \(readableListStyle(afterStyle))"
            }
            if beforeIndent != afterIndent {
                return "List indent: \(beforeIndent) -> \(afterIndent)"
            }
        case let (.codeBlock(_, beforeLanguage), .codeBlock(_, afterLanguage)) where beforeLanguage != afterLanguage:
            return "Code language: \(beforeLanguage ?? "plain") -> \(afterLanguage ?? "plain")"
        default:
            break
        }

        guard let beforeText = before.content.textContent, let afterText = after.content.textContent else {
            return nil
        }

        if let toggle = booleanAttributeSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.bold,
            label: "Bold"
        ) {
            return toggle
        }
        if let toggle = booleanAttributeSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.italic,
            label: "Italic"
        ) {
            return toggle
        }
        if let toggle = booleanAttributeSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.underline,
            label: "Underline"
        ) {
            return toggle
        }
        if let toggle = booleanAttributeSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.strikethrough,
            label: "Strikethrough"
        ) {
            return toggle
        }
        if let toggle = booleanAttributeSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.code,
            label: "Code style"
        ) {
            return toggle
        }
        if let toggle = booleanAttributeSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.superscript,
            label: "Superscript"
        ) {
            return toggle
        }
        if let toggle = booleanAttributeSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.subscript,
            label: "Subscript"
        ) {
            return toggle
        }
        if let link = linkSummary(from: beforeText, to: afterText) {
            return link
        }
        if let color = colorSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.color,
            label: "Text color"
        ) {
            return color
        }
        if let color = colorSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.highlightColor,
            label: "Highlight"
        ) {
            return color
        }
        if let fontSize = optionalValueSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.fontSize,
            formatter: { beforeValue, afterValue in
            "Font size: \(formatCGFloat(beforeValue)) -> \(formatCGFloat(afterValue))"
            }
        ) {
            return fontSize
        }
        if let fontFamily = optionalValueSummary(
            from: beforeText,
            to: afterText,
            keyPath: \.fontFamily,
            formatter: { beforeValue, afterValue in
            "Font family: \(beforeValue ?? "system") -> \(afterValue ?? "system")"
            }
        ) {
            return fontFamily
        }

        return nil
    }

    private func structuralSummary(
        count: Int,
        singular: String,
        plural: String,
        preview: String
    ) -> String {
        let title = count == 1 ? singular : "\(count) \(plural.lowercased())"
        guard !preview.isEmpty else { return title }
        return "\(title): \(String(preview.prefix(72)))"
    }

    private func trimmedPreview(for text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(72))
    }

    private func booleanAttributeSummary(
        from before: TextContent,
        to after: TextContent,
        keyPath: KeyPath<TextAttributes, Bool>,
        label: String
    ) -> String? {
        guard
            let beforeValue = uniformValue(before, keyPath: keyPath),
            let afterValue = uniformValue(after, keyPath: keyPath),
            beforeValue != afterValue
        else {
            return nil
        }

        return "\(label) \(afterValue ? "on" : "off")"
    }

    private func linkSummary(from before: TextContent, to after: TextContent) -> String? {
        guard
            let beforeValue = uniformOptionalValue(before, keyPath: \.link),
            let afterValue = uniformOptionalValue(after, keyPath: \.link),
            beforeValue != afterValue
        else {
            return nil
        }

        switch (beforeValue, afterValue) {
        case (.none, .some):
            return "Link added"
        case (.some, .none):
            return "Link removed"
        case (.some, .some):
            return "Link updated"
        case (.none, .none):
            return nil
        }
    }

    private func colorSummary(
        from before: TextContent,
        to after: TextContent,
        keyPath: KeyPath<TextAttributes, ColorValue?>,
        label: String
    ) -> String? {
        guard
            let beforeValue = uniformOptionalValue(before, keyPath: keyPath),
            let afterValue = uniformOptionalValue(after, keyPath: keyPath),
            beforeValue != afterValue
        else {
            return nil
        }

        return "\(label): \(readableColor(beforeValue)) -> \(readableColor(afterValue))"
    }

    private func optionalValueSummary<T: Equatable>(
        from before: TextContent,
        to after: TextContent,
        keyPath: KeyPath<TextAttributes, T?>,
        formatter: (T?, T?) -> String
    ) -> String? {
        guard
            let beforeValue = uniformOptionalValue(before, keyPath: keyPath),
            let afterValue = uniformOptionalValue(after, keyPath: keyPath),
            beforeValue != afterValue
        else {
            return nil
        }

        return formatter(beforeValue, afterValue)
    }

    private func uniformValue(
        _ content: TextContent,
        keyPath: KeyPath<TextAttributes, Bool>
    ) -> Bool? {
        guard let first = content.runs.first?.attributes[keyPath: keyPath] else { return nil }
        return content.runs.allSatisfy({ $0.attributes[keyPath: keyPath] == first }) ? first : nil
    }

    private func uniformOptionalValue<T: Equatable>(
        _ content: TextContent,
        keyPath: KeyPath<TextAttributes, T?>
    ) -> T?? {
        guard let first = content.runs.first?.attributes[keyPath: keyPath] else { return nil }
        return content.runs.allSatisfy({ $0.attributes[keyPath: keyPath] == first }) ? first : nil
    }

    private func readableBlockType(_ type: BlockType) -> String {
        switch type {
        case .paragraph:
            "paragraph"
        case .heading:
            "heading"
        case .blockQuote:
            "quote"
        case .codeBlock:
            "code block"
        case .list:
            "list"
        case .table:
            "table"
        case .image:
            "image"
        case .divider:
            "divider"
        case .embed:
            "embed"
        }
    }

    private func readableListStyle(_ style: ListStyle) -> String {
        switch style {
        case .bullet:
            "bullets"
        case .numbered:
            "numbered"
        case .checklist:
            "checklist"
        }
    }

    private func readableColor(_ color: ColorValue?) -> String {
        color.map { "#\($0.hex)" } ?? "none"
    }

    private func formatCGFloat(_ value: CGFloat?) -> String {
        guard let value else { return "default" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.01 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }
}
