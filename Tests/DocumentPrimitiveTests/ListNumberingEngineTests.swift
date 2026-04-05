import Foundation
import Testing
@testable import DocumentPrimitive

@Suite("ListNumberingEngine Tests")
struct ListNumberingEngineTests {
    @Test func rendersFormatStringWithCounters() {
        let definition = ListDefinition(
            id: "outline",
            levels: [
                ListLevelFormat(style: .decimal, format: "%1."),
                ListLevelFormat(style: .upperRoman, format: "%1.%2."),
            ]
        )

        let result = ListNumberingEngine().render(definition: definition, level: 1, counters: [3, 2])
        #expect(result == "3.II.")
    }
}
