import Foundation
import RichTextPrimitive
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
        if let projectedTarget = projectedReviewTargetPage(in: pages) {
            return pageScrollKey(for: projectedTarget)
        }
        return resolvedCurrentPage(in: pages).map(pageScrollKey(for:))
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

    private func projectedReviewTargetPage(in pages: [ComputedPage]) -> ComputedPage? {
        guard changeTracker.showChanges == .original,
              let change = currentTrackedChange,
              let context = trackedChangeContexts[change.id]
        else {
            return nil
        }

        let projectedDocument = projectedOriginalDocument()
        let targetBlockIDs = projectedTargetBlockIDs(for: context, in: projectedDocument)
        guard !targetBlockIDs.isEmpty else { return nil }

        return pages.first { page in
            page.sectionID == context.sectionID &&
                pageContainsAnyBlock(page, blockIDs: targetBlockIDs, in: projectedDocument)
        }
    }

    private func projectedTargetBlockIDs(
        for context: TrackedChangeContext,
        in document: Document
    ) -> [BlockID] {
        switch context.operation {
        case let .replace(before, _):
            return [before.id]
        case let .delete(blocks, _):
            return blocks.map(\.id)
        case let .insert(_, index):
            guard let section = document.section(context.sectionID) else { return [] }
            if section.blocks.indices.contains(index) {
                return [section.blocks[index].id]
            }
            if index > 0, section.blocks.indices.contains(index - 1) {
                return [section.blocks[index - 1].id]
            }
            return section.blocks.first.map { [$0.id] } ?? []
        }
    }

    private func pageContainsAnyBlock(
        _ page: ComputedPage,
        blockIDs: [BlockID],
        in document: Document
    ) -> Bool {
        let targetIDs = Set(blockIDs)

        if !page.blockPlacements.isEmpty {
            let visibleIDs = Set(page.blockPlacements.map(\.blockID))
            return !visibleIDs.isDisjoint(with: targetIDs)
        }

        guard let section = document.section(page.sectionID) else { return false }
        for range in page.blockRanges {
            for index in range.startIndex...range.endIndex where section.blocks.indices.contains(index) {
                if targetIDs.contains(section.blocks[index].id) {
                    return true
                }
            }
        }

        return false
    }
}
