import DocumentPrimitive
import FilePreviewPrimitive
import RichTextPrimitive
import SwiftUI

@MainActor
public struct DocumentAttachmentPreview: View {
    private let attachment: DocumentPreviewAttachment
    private let showFileInfo: Bool
    private let showsPresentationSwitcher: Bool

    public init(
        attachment: DocumentPreviewAttachment,
        showFileInfo: Bool = false,
        showsPresentationSwitcher: Bool = true
    ) {
        self.attachment = attachment
        self.showFileInfo = showFileInfo
        self.showsPresentationSwitcher = showsPresentationSwitcher
    }

    public init?(
        block: Block,
        resolver: DocumentPreviewAttachmentResolver = DocumentPreviewAttachmentResolver(),
        showFileInfo: Bool = false,
        showsPresentationSwitcher: Bool = true
    ) {
        guard let attachment = resolver.attachment(for: block) else { return nil }
        self.init(
            attachment: attachment,
            showFileInfo: showFileInfo,
            showsPresentationSwitcher: showsPresentationSwitcher
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FilePreview(
                item: attachment.previewItem,
                showFileInfo: showFileInfo,
                presentation: .rendered,
                showsPresentationSwitcher: showsPresentationSwitcher
            )
            .frame(minHeight: 240)

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.title)
                    .font(.headline)

                if let caption = attachment.caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
