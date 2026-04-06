import Foundation
import TrackChangesPrimitive

struct DocumentReviewProjection {
    let document: Document
    let pages: [ComputedPage]
    let isReadOnly: Bool
}

@MainActor
extension DocumentEditorState {
    var reviewDisplayProjection: DocumentReviewProjection {
        switch changeTracker.showChanges {
        case .showAll, .showOnlyMine:
            return DocumentReviewProjection(
                document: document,
                pages: layoutEngine.pages,
                isReadOnly: false
            )
        case .final_:
            return DocumentReviewProjection(
                document: document,
                pages: layoutEngine.pages,
                isReadOnly: true
            )
        case .original:
            let document = projectedOriginalDocument()
            let engine = PageLayoutEngine(document: document)
            engine.reflow()
            return DocumentReviewProjection(
                document: document,
                pages: engine.pages,
                isReadOnly: true
            )
        }
    }

    var isProjectedReviewMode: Bool {
        reviewDisplayProjection.isReadOnly
    }

    func currentPageScrollKey(in pages: [ComputedPage]) -> String? {
        resolvedCurrentPage(in: pages).map(pageScrollKey(for:))
    }

    private func projectedOriginalDocument() -> Document {
        var projected = document

        for change in changeTracker.changes.reversed() {
            guard let context = trackedChangeContexts[change.id] else { continue }
            applyOriginalProjection(context, to: &projected)
        }

        return projected
    }

    private func applyOriginalProjection(
        _ context: TrackedChangeContext,
        to document: inout Document
    ) {
        guard let sectionIndex = document.sectionIndex(context.sectionID) else { return }
        var blocks = document.sections[sectionIndex].blocks

        switch context.operation {
        case let .replace(before, after):
            guard let index = blocks.firstIndex(where: { $0.id == after.id }) else { return }
            blocks[index] = before
        case let .insert(insertedBlocks, _):
            for block in insertedBlocks.reversed() {
                if let index = blocks.firstIndex(where: { $0.id == block.id }) {
                    blocks.remove(at: index)
                }
            }
        case let .delete(deletedBlocks, index):
            let insertionIndex = min(max(index, 0), blocks.count)
            blocks.insert(contentsOf: deletedBlocks, at: insertionIndex)
        }

        document.sections[sectionIndex].blocks = blocks
    }

    private func resolvedCurrentPage(in pages: [ComputedPage]) -> ComputedPage? {
        if let currentSection {
            if let exact = pages.first(where: {
                $0.sectionID == currentSection && $0.pageNumber == currentPage
            }) {
                return exact
            }

            if let sameSection = pages.first(where: { $0.sectionID == currentSection }) {
                return sameSection
            }
        }

        return pages.first(where: { $0.pageNumber == currentPage }) ?? pages.first
    }
}
