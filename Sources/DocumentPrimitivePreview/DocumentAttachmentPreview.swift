import DocumentPrimitive
import FilePreviewPrimitive
import RichTextPrimitive
import SwiftUI

@MainActor
public struct DocumentAttachmentPreview: View {
    @Environment(\.documentTheme) private var theme
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
        VStack(alignment: .leading, spacing: theme.spacing.attachmentPreviewSpacing) {
            FilePreview(
                item: attachment.previewItem,
                showFileInfo: showFileInfo,
                presentation: .rendered,
                showsPresentationSwitcher: showsPresentationSwitcher
            )
            .frame(minHeight: theme.metrics.attachmentPreviewMinHeight)

            VStack(alignment: .leading, spacing: theme.spacing.attachmentTitleCaptionSpacing) {
                Text(attachment.title)
                    .font(theme.typography.attachmentTitle)

                if let caption = attachment.caption {
                    Text(caption)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.secondary)
                }
            }
        }
    }
}
