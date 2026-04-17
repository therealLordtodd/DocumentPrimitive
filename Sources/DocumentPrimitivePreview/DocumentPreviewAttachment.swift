import DocumentPrimitive
import Foundation
import FilePreviewPrimitive
import RichTextPrimitive

public enum DocumentPreviewAttachmentKind: String, Sendable {
    case image
    case embed
}

public struct DocumentPreviewAttachment: Identifiable, Sendable {
    public let id: String
    public let blockID: BlockID
    public let kind: DocumentPreviewAttachmentKind
    public let title: String
    public let caption: String?
    public let previewItem: PreviewItem

    public init(
        id: String,
        blockID: BlockID,
        kind: DocumentPreviewAttachmentKind,
        title: String,
        caption: String? = nil,
        previewItem: PreviewItem
    ) {
        self.id = id
        self.blockID = blockID
        self.kind = kind
        self.title = title
        self.caption = caption
        self.previewItem = previewItem
    }
}
