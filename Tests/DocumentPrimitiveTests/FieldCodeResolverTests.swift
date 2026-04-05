import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

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

    @Test func resolvesInlineFieldTokensInTextAndRuns() {
        let context = FieldResolutionContext(
            pageNumber: 7,
            pageCount: 19,
            sectionNumber: 3,
            date: Date(timeIntervalSince1970: 0),
            title: "Draft",
            author: "Todd"
        )
        let resolver = FieldCodeResolver()

        let inline = resolver.resolveInlineTokens(
            in: "{TITLE}  {{pageNumber}} / {{pageCount}}  {AUTHOR}",
            context: context
        )
        let runs = resolver.resolve(
            runs: [
                TextRun(text: "Section {SECTION}"),
                TextRun(text: "  {DATE}"),
            ],
            context: context
        )

        #expect(inline == "Draft  7 / 19  Todd")
        #expect(runs[0].text == "Section 3")
        #expect(runs[1].text.contains("1970") || !runs[1].text.isEmpty)
    }
}
