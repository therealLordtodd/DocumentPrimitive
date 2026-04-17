import DocumentPrimitive
import FilePreviewPrimitive
import SwiftUI

@MainActor
public struct DocumentAttachmentGallery: View {
    private let attachments: [DocumentPreviewAttachment]
    private let configuration: GalleryConfiguration
    private let currentIndex: Binding<Int>?
    private let onDismiss: (() -> Void)?

    public init(
        attachments: [DocumentPreviewAttachment],
        configuration: GalleryConfiguration = .init(),
        currentIndex: Binding<Int>? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.attachments = attachments
        self.configuration = configuration
        self.currentIndex = currentIndex
        self.onDismiss = onDismiss
    }

    public init(
        document: Document,
        resolver: DocumentPreviewAttachmentResolver = DocumentPreviewAttachmentResolver(),
        configuration: GalleryConfiguration = .init(),
        currentIndex: Binding<Int>? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            attachments: resolver.attachments(in: document),
            configuration: configuration,
            currentIndex: currentIndex,
            onDismiss: onDismiss
        )
    }

    public var body: some View {
        PreviewGallery(
            items: attachments.map(\.previewItem),
            configuration: configuration,
            currentIndex: currentIndex,
            onDismiss: onDismiss
        )
    }
}
