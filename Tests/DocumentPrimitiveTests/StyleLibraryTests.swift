import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@Suite("StyleLibrary Tests")
struct StyleLibraryTests {
    @Test func standardLibraryIncludesExpectedStyles() {
        let library = DocumentStyleLibrary.standard
        #expect(library.paragraphStyles["Normal"] != nil)
        #expect(library.paragraphStyles["Heading 1"] != nil)
        #expect(library.characterStyles["Strong"]?.bold == true)
    }

    @MainActor
    @Test func documentStyleLibraryBuildsRichTextStyleSheet() {
        let library = DocumentStyleLibrary(
            paragraphStyles: [
                "Normal": ParagraphStyle(fontFamily: "Georgia", fontSize: 16),
                "Heading 1": ParagraphStyle(fontFamily: "Georgia", fontSize: 28, fontWeight: .bold),
                "Block Quote": ParagraphStyle(firstLineIndent: 8, indent: 20),
                "List Paragraph": ParagraphStyle(firstLineIndent: 12, indent: 24),
                "Code": ParagraphStyle(fontFamily: "Menlo", fontSize: 13),
                "Title": ParagraphStyle(fontFamily: "Avenir Next", fontSize: 34, fontWeight: .bold),
            ]
        )

        let styleSheet = library.textStyleSheet()

        #expect(styleSheet.defaultStyle.fontFamily == "Georgia")
        #expect(styleSheet.headingStyle(level: 1).fontSize == 28)
        #expect(styleSheet.blockQuoteStyle.indent == 20)
        #expect(styleSheet.listStyles[.bullet]?.indent == 24)
        #expect(styleSheet.codeBlockStyle.fontFamily == "Menlo")
        #expect(styleSheet.customStyles["Title"]?.fontFamily == "Avenir Next")
    }
}
