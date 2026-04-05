import Foundation
import Testing
@testable import DocumentPrimitive

@Suite("StyleLibrary Tests")
struct StyleLibraryTests {
    @Test func standardLibraryIncludesExpectedStyles() {
        let library = DocumentStyleLibrary.standard
        #expect(library.paragraphStyles["Normal"] != nil)
        #expect(library.paragraphStyles["Heading 1"] != nil)
        #expect(library.characterStyles["Strong"]?.bold == true)
    }
}
