import Foundation
import RichTextPrimitive

public struct TableStyleDefinition: Codable, Sendable, Equatable {
    public var name: String
    public var bandedRows: Bool
    public var headerEmphasis: Bool

    public init(
        name: String,
        bandedRows: Bool = true,
        headerEmphasis: Bool = true
    ) {
        self.name = name
        self.bandedRows = bandedRows
        self.headerEmphasis = headerEmphasis
    }
}

public struct DocumentStyleLibrary: Codable, Sendable, Equatable {
    public var characterStyles: [String: TextAttributes]
    public var paragraphStyles: [String: ParagraphStyle]
    public var listDefinitions: [ListDefinitionID: ListDefinition]
    public var tableStyles: [String: TableStyleDefinition]

    public init(
        characterStyles: [String: TextAttributes] = [:],
        paragraphStyles: [String: ParagraphStyle] = [:],
        listDefinitions: [ListDefinitionID: ListDefinition] = [:],
        tableStyles: [String: TableStyleDefinition] = [:]
    ) {
        self.characterStyles = characterStyles
        self.paragraphStyles = paragraphStyles
        self.listDefinitions = listDefinitions
        self.tableStyles = tableStyles
    }

    public static var standard: DocumentStyleLibrary {
        let decimalList = ListDefinition(
            id: "standard-decimal",
            levels: [
                ListLevelFormat(style: .decimal, format: "%1."),
                ListLevelFormat(style: .lowerAlpha, format: "%1.%2."),
                ListLevelFormat(style: .lowerRoman, format: "%1.%2.%3."),
            ]
        )

        return DocumentStyleLibrary(
            characterStyles: [
                "Strong": TextAttributes(bold: true),
                "Emphasis": TextAttributes(italic: true),
                "Code": TextAttributes(code: true, fontFamily: "Menlo"),
            ],
            paragraphStyles: [
                "Normal": ParagraphStyle(),
                "Heading 1": ParagraphStyle(fontSize: 30, fontWeight: .bold, paragraphSpacing: 14),
                "Heading 2": ParagraphStyle(fontSize: 24, fontWeight: .bold, paragraphSpacing: 12),
                "Heading 3": ParagraphStyle(fontSize: 20, fontWeight: .semibold, paragraphSpacing: 10),
                "Title": ParagraphStyle(fontSize: 34, fontWeight: .bold, paragraphSpacing: 16),
                "Subtitle": ParagraphStyle(fontSize: 18, fontWeight: .medium, paragraphSpacing: 12),
                "Body Text": ParagraphStyle(),
                "Block Quote": ParagraphStyle(firstLineIndent: 10, indent: 20),
                "List Paragraph": ParagraphStyle(firstLineIndent: 9, indent: 18),
                "Code": ParagraphStyle(fontFamily: "Menlo", fontSize: 13),
            ],
            listDefinitions: [decimalList.id: decimalList],
            tableStyles: [
                "Default": TableStyleDefinition(name: "Default"),
            ]
        )
    }
}

@MainActor
extension DocumentStyleLibrary {
    public func textStyleSheet() -> TextStyleSheet {
        let defaultStyle = paragraphStyles["Normal"]
            ?? paragraphStyles["Body Text"]
            ?? ParagraphStyle()

        let headingStyles = Dictionary(uniqueKeysWithValues: (1...6).compactMap { level in
            paragraphStyles["Heading \(level)"].map { (level, $0) }
        })

        let blockQuoteStyle = paragraphStyles["Block Quote"] ?? defaultStyle
        let codeBlockStyle = paragraphStyles["Code"] ?? ParagraphStyle(fontFamily: "Menlo", fontSize: 13)
        let listParagraphStyle = paragraphStyles["List Paragraph"] ?? defaultStyle
        let customStyles = paragraphStyles.filter { name, _ in
            !(name == "Normal"
                || name == "Body Text"
                || name == "Block Quote"
                || name == "Code"
                || name == "List Paragraph"
                || name.hasPrefix("Heading "))
        }

        return TextStyleSheet(
            defaultStyle: defaultStyle,
            headingStyles: headingStyles,
            blockQuoteStyle: blockQuoteStyle,
            codeBlockStyle: codeBlockStyle,
            listStyles: [
                .bullet: listParagraphStyle,
                .numbered: listParagraphStyle,
                .checklist: listParagraphStyle,
            ],
            customStyles: customStyles
        )
    }
}
