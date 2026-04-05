import CoreGraphics
import Foundation
import Testing
@testable import DocumentPrimitive
@testable import RichTextPrimitive

@Suite("BlockFragmentResolver Tests")
struct BlockFragmentResolverTests {
    @Test func paragraphFragmentsSliceTextAndAddContinuations() {
        let block = Block(
            id: "body",
            type: .paragraph,
            content: .text(.plain("1234567890"))
        )
        let placement = BlockFragmentPlacement(
            id: UUID(),
            blockID: "body",
            blockIndex: 0,
            frame: .zero,
            isPartial: true,
            partialRange: 0...50,
            itemHeight: 100
        )

        let resolved = BlockFragmentResolver().block(for: block, placement: placement)

        guard case let .text(content) = resolved.content else {
            Issue.record("Expected paragraph text content")
            return
        }

        #expect(content.plainText == "12345…")
    }

    @Test func codeBlockFragmentsSliceCodeAndAddLeadingContinuation() {
        let block = Block(
            id: "code",
            type: .codeBlock,
            content: .codeBlock(code: "abcdefghij", language: "swift")
        )
        let placement = BlockFragmentPlacement(
            id: UUID(),
            blockID: "code",
            blockIndex: 0,
            frame: .zero,
            isPartial: true,
            partialRange: 50...100,
            itemHeight: 100
        )

        let resolved = BlockFragmentResolver().block(for: block, placement: placement)

        guard case let .codeBlock(code, language) = resolved.content else {
            Issue.record("Expected code block content")
            return
        }

        #expect(code == "…fghij")
        #expect(language == "swift")
    }
}
