import Foundation
import Testing
import UniformTypeIdentifiers
@testable import DocumentPrimitive
@testable import DocumentPrimitivePreview
@testable import RichTextPrimitive

@Suite("DocumentPrimitivePreview Tests")
struct DocumentPreviewAttachmentResolverTests {
    @Test func imageBlockWithInlineDataProducesPreviewAttachment() throws {
        let resolver = DocumentPreviewAttachmentResolver()
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47,
            0x0D, 0x0A, 0x1A, 0x0A,
        ])
        let block = Block(
            id: "image-block",
            type: .image,
            content: .image(
                ImageContent(
                    data: pngData,
                    altText: "Floorplan"
                )
            )
        )

        let attachment = try #require(resolver.attachment(for: block))

        #expect(attachment.kind == .image)
        #expect(attachment.blockID == "image-block")
        #expect(attachment.title == "Floorplan")
        #expect(attachment.caption == "Floorplan")
        #expect(attachment.previewItem.fileType == UTType.png)
        #expect(attachment.previewItem.url.isFileURL)
    }

    @Test func embedBlockWithFileMetadataProducesPreviewAttachment() throws {
        let resolver = DocumentPreviewAttachmentResolver()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("document-preview-report")
            .appendingPathExtension("pdf")
        try Data("pdf".utf8).write(to: fileURL, options: .atomic)

        let block = Block(
            id: "embed-block",
            type: .embed,
            content: .embed(
                EmbedContent(
                    kind: "pdf",
                    payload: "Quarterly report",
                    metadata: [
                        "url": .string(fileURL.absoluteString),
                        "title": .string("Q1 Report"),
                    ]
                )
            )
        )

        let attachment = try #require(resolver.attachment(for: block))

        #expect(attachment.kind == .embed)
        #expect(attachment.title == "Q1 Report")
        #expect(attachment.caption == "Quarterly report")
        #expect(attachment.previewItem.url == fileURL)
        #expect(attachment.previewItem.fileType == UTType.pdf)
    }

    @Test func documentAttachmentsPreserveBlockOrderAndSkipUnsupportedRemoteItems() {
        let resolver = DocumentPreviewAttachmentResolver()
        let localImageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("document-preview-image")
            .appendingPathExtension("png")

        let document = Document(
            title: "Attachments",
            sections: [
                DocumentSection(
                    id: "section",
                    blocks: [
                        Block(
                            id: "remote-image",
                            type: .image,
                            content: .image(
                                ImageContent(
                                    url: URL(string: "https://example.com/remote.png"),
                                    altText: "Remote"
                                )
                            )
                        ),
                        Block(
                            id: "local-image",
                            type: .image,
                            content: .image(
                                ImageContent(
                                    url: localImageURL,
                                    altText: "Local image"
                                )
                            )
                        ),
                        Block(
                            id: "embed",
                            type: .embed,
                            content: .embed(
                                EmbedContent(
                                    kind: "markdown",
                                    metadata: [
                                        "path": .string("/tmp/spec.md"),
                                        "title": .string("Spec"),
                                    ]
                                )
                            )
                        ),
                    ]
                ),
            ]
        )

        let attachments = resolver.attachments(in: document)

        #expect(attachments.map(\.blockID.rawValue) == ["local-image", "embed"])
        #expect(attachments.map(\.title) == ["document-preview-image.png", "Spec"])
    }
}
