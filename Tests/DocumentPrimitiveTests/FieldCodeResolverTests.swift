import Foundation
import Testing
@testable import DocumentPrimitive

@Suite("FieldCodeResolver Tests")
struct FieldCodeResolverTests {
    @Test func resolvesStandardFields() {
        let context = FieldResolutionContext(
            pageNumber: 4,
            pageCount: 12,
            sectionNumber: 2,
            date: Date(timeIntervalSince1970: 0),
            title: "Draft",
            author: "Todd"
        )
        let resolver = FieldCodeResolver()

        #expect(resolver.resolve(.pageNumber, context: context) == "4")
        #expect(resolver.resolve(.pageCount, context: context) == "12")
        #expect(resolver.resolve(.sectionNumber, context: context) == "2")
        #expect(resolver.resolve(.title, context: context) == "Draft")
        #expect(resolver.resolve(.author, context: context) == "Todd")
    }
}
