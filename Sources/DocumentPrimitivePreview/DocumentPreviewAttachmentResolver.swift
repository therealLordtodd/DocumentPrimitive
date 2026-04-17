import DocumentPrimitive
import Foundation
import FilePreviewPrimitive
import RichTextPrimitive
import UniformTypeIdentifiers

public struct DocumentPreviewAttachmentResolver: Sendable {
    public init() {}

    public func attachment(for block: Block) -> DocumentPreviewAttachment? {
        switch block.content {
        case let .image(content):
            return imageAttachment(for: block.id, content: content)
        case let .embed(content):
            return embedAttachment(for: block.id, content: content)
        default:
            return nil
        }
    }

    public func attachments(in section: DocumentSection) -> [DocumentPreviewAttachment] {
        section.blocks.compactMap(attachment(for:))
    }

    public func attachments(in document: Document) -> [DocumentPreviewAttachment] {
        document.sections.flatMap(attachments(in:))
    }

    private func imageAttachment(
        for blockID: BlockID,
        content: ImageContent
    ) -> DocumentPreviewAttachment? {
        let title = resolvedImageTitle(content)
        let caption = normalizedCaption(content.altText)

        if let data = content.data,
           let materialized = materializedPreviewItem(
                stableIdentity: "image:\(blockID.rawValue)",
                title: title,
                data: data,
                fileType: inferredImageType(content: content)
           ) {
            return DocumentPreviewAttachment(
                id: "image:\(blockID.rawValue)",
                blockID: blockID,
                kind: .image,
                title: title,
                caption: caption,
                previewItem: materialized
            )
        }

        guard let url = content.url else {
            return nil
        }

        let previewItem = PreviewItem(
            stableIdentity: "image:\(blockID.rawValue)",
            url: url,
            title: title,
            fileType: inferredType(from: url) ?? .image
        )
        return DocumentPreviewAttachment(
            id: "image:\(blockID.rawValue)",
            blockID: blockID,
            kind: .image,
            title: title,
            caption: caption,
            previewItem: previewItem
        )
    }

    private func embedAttachment(
        for blockID: BlockID,
        content: EmbedContent
    ) -> DocumentPreviewAttachment? {
        let resolved = resolvedEmbedSource(content)

        if let data = resolved.data,
           let materialized = materializedPreviewItem(
                stableIdentity: "embed:\(blockID.rawValue)",
                title: resolved.title,
                data: data,
                fileType: resolved.fileType ?? .data
           ) {
            return DocumentPreviewAttachment(
                id: "embed:\(blockID.rawValue)",
                blockID: blockID,
                kind: .embed,
                title: resolved.title,
                caption: normalizedCaption(content.payload),
                previewItem: materialized
            )
        }

        guard let url = resolved.url else {
            return nil
        }

        let previewItem = PreviewItem(
            stableIdentity: "embed:\(blockID.rawValue)",
            url: url,
            title: resolved.title,
            fileType: resolved.fileType ?? inferredType(from: url)
        )
        return DocumentPreviewAttachment(
            id: "embed:\(blockID.rawValue)",
            blockID: blockID,
            kind: .embed,
            title: resolved.title,
            caption: normalizedCaption(content.payload),
            previewItem: previewItem
        )
    }

    private func materializedPreviewItem(
        stableIdentity: String,
        title: String,
        data: Data,
        fileType: UTType
    ) -> PreviewItem? {
        let fileURL = materializedTemporaryURL(
            stableIdentity: stableIdentity,
            fileType: fileType,
            title: title
        )

        do {
            try data.write(to: fileURL, options: .atomic)
            return PreviewItem(
                stableIdentity: stableIdentity,
                url: fileURL,
                title: title,
                fileType: fileType
            )
        } catch {
            return nil
        }
    }

    private func materializedTemporaryURL(
        stableIdentity: String,
        fileType: UTType,
        title: String
    ) -> URL {
        let ext = preferredFilenameExtension(for: fileType)
        let safeIdentity = stableIdentity
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let safeTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let filename = safeTitle.isEmpty ? safeIdentity : safeTitle
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("document-preview-\(safeIdentity)-\(filename)")
            .appendingPathExtension(ext)
    }

    private func preferredFilenameExtension(for type: UTType) -> String {
        type.preferredFilenameExtension ?? "bin"
    }

    private func inferredImageType(content: ImageContent) -> UTType {
        if let url = content.url,
           let type = inferredType(from: url) {
            return type
        }

        if let data = content.data,
           let type = inferredType(fromImageData: data) {
            return type
        }

        return .image
    }

    private func inferredType(from url: URL) -> UTType? {
        guard !url.pathExtension.isEmpty else { return nil }
        return UTType(filenameExtension: url.pathExtension)
    }

    private func inferredType(fromImageData data: Data) -> UTType? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return .gif
        }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]), data.dropFirst(8).starts(with: [0x57, 0x45, 0x42, 0x50]) {
            return .webP
        }
        return nil
    }

    private func resolvedImageTitle(_ content: ImageContent) -> String {
        if let url = content.url {
            let last = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !last.isEmpty {
                return last
            }
        }

        if let altText = normalizedCaption(content.altText) {
            return altText
        }

        return "Image"
    }

    private func normalizedCaption(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func resolvedEmbedSource(
        _ content: EmbedContent
    ) -> (url: URL?, data: Data?, fileType: UTType?, title: String) {
        let metadataURL = urlValue(forKeyCandidates: ["url", "fileURL", "path"], metadata: content.metadata)
        let payloadURL = content.payload.flatMap(URL.init(string:))
        let resolvedURL = [metadataURL, payloadURL]
            .compactMap { candidate -> URL? in
                guard let candidate else { return nil }
                if candidate.isFileURL { return candidate }
                if candidate.scheme == nil {
                    return URL(fileURLWithPath: candidate.absoluteString)
                }
                return candidate
            }
            .first

        let metadataType = metadataString(
            forKeyCandidates: ["uti", "fileType"],
            metadata: content.metadata
        ).map { identifier in
            UTType(importedAs: identifier)
        }
        let payloadType = content.payload
            .flatMap(URL.init(string:))
            .flatMap(inferredType(from:))
        let fileType = metadataType
            ?? resolvedURL.flatMap(inferredType(from:))
            ?? payloadType
            ?? fallbackEmbedType(kind: content.kind)

        let title =
            metadataString(forKeyCandidates: ["title", "filename", "name"], metadata: content.metadata)
            ?? resolvedURL?.lastPathComponent
            ?? content.kind.uppercased()

        return (url: resolvedURL, data: nil, fileType: fileType, title: title)
    }

    private func metadataString(
        forKeyCandidates keys: [String],
        metadata: [String: MetadataValue]
    ) -> String? {
        for key in keys {
            if case let .string(value)? = metadata[key],
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private func urlValue(
        forKeyCandidates keys: [String],
        metadata: [String: MetadataValue]
    ) -> URL? {
        metadataString(forKeyCandidates: keys, metadata: metadata).flatMap(URL.init(string:))
    }

    private func fallbackEmbedType(kind: String) -> UTType {
        switch kind.lowercased() {
        case "pdf":
            return .pdf
        case "markdown", "md":
            return UTType(filenameExtension: "md") ?? .plainText
        case "html", "htm":
            return .html
        case "csv":
            return .commaSeparatedText
        case "text", "txt":
            return .plainText
        default:
            return .data
        }
    }
}
