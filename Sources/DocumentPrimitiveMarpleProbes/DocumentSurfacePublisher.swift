import DocumentPrimitive
import MarpleCore

/// Publishes semantic surface snapshots for the document editor, enabling
/// Marple probes to inspect document state without app-specific knowledge.
public struct DocumentSurfacePublisher: SemanticSurfacePublisher, Sendable {
    private let document: Document

    /// Creates a publisher for the given document.
    ///
    /// - Parameter document: The document to publish surface state for.
    public init(document: Document) {
        self.document = document
    }

    public func snapshot() -> SemanticSurfaceSnapshot {
        let pageCount = document.sections.reduce(0) { total, section in
            total + max(section.blocks.isEmpty ? 0 : 1, 1)
        }
        let sectionCount = document.sections.count
        let totalBlocks = document.sections.reduce(0) { $0 + $1.blocks.count }
        let hasContent = totalBlocks > 0
        let detailMode = hasContent ? "editing" : "empty"

        var contextItems: [String: String] = [
            "pageCount": "\(pageCount)",
            "sectionCount": "\(sectionCount)",
            "blockCount": "\(totalBlocks)",
        ]

        if let author = document.settings.author {
            contextItems["author"] = author
        }

        let summaryParts = [
            "\(sectionCount) section\(sectionCount == 1 ? "" : "s")",
            "\(totalBlocks) block\(totalBlocks == 1 ? "" : "s")",
        ]
        let summary = "\(document.title): \(summaryParts.joined(separator: ", "))"

        return SemanticSurfaceSnapshot(
            surfaceIdentifier: "document.editor",
            isReady: hasContent,
            detailMode: detailMode,
            selectedEntityIdentifiers: [],
            contextItems: contextItems,
            summary: summary
        )
    }
}
