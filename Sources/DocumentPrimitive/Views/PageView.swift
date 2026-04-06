import BookmarkPrimitive
import CommentPrimitive
import Foundation
import RichTextPrimitive
import SwiftUI
import TrackChangesPrimitive
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct PageView: View {
    @Bindable private var state: DocumentEditorState
    @State private var commentDrafts: [CommentID: String] = [:]
    @State private var replyDrafts: [CommentID: String] = [:]
    @Environment(\.pageInlineBlockRenderer) private var pageInlineBlockRenderer
    private let page: ComputedPage
    private let fieldCodeResolver = FieldCodeResolver()
    private let footnoteDisplayResolver = FootnoteDisplayResolver()
    private let blockFragmentResolver = BlockFragmentResolver()

    public init(state: DocumentEditorState, page: ComputedPage) {
        self.state = state
        self.page = page
    }

    public var body: some View {
        let section = state.document.section(page.sectionID)
        let sectionBlocks = section?.blocks ?? []
        let isActivePage = state.currentPage == page.pageNumber && state.currentSection == page.sectionID
        let footnoteHeight = footnoteAreaHeight
        let contentBodyHeight = max(page.template.contentHeight - footnoteHeight, 120)

        VStack(spacing: 0) {
            pageHeader(isActive: isActivePage)
                .frame(width: page.template.contentWidth, height: page.template.headerHeight, alignment: .bottom)
                .padding(.top, page.template.margins.top)

            contentArea(sectionBlocks: sectionBlocks, isActive: isActivePage, contentBodyHeight: contentBodyHeight)
                .frame(width: page.template.contentWidth, height: page.template.contentHeight, alignment: .top)

            pageFooter(isActive: isActivePage)
                .frame(width: page.template.contentWidth, height: page.template.footerHeight, alignment: .top)
                .padding(.bottom, page.template.margins.bottom)
        }
        .frame(
            width: page.template.size.width,
            height: page.template.size.height,
            alignment: .top
        )
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                Text("Page \(page.pageNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !pageAnnotations.isEmpty {
                    VStack(alignment: .trailing, spacing: 6) {
                        ForEach(pageAnnotations) { annotation in
                            annotationBadge(annotation)
                        }
                    }
                }
            }
            .padding(12)
        }
        .onTapGesture {
            state.currentPage = page.pageNumber
            state.currentSection = page.sectionID
        }
    }

    @ViewBuilder
    private func pageHeader(isActive: Bool) -> some View {
        if page.template.headerHeight > 0 || page.header != nil || isActive {
            headerFooterView(
                content: page.header,
                slots: headerSlots,
                isActive: isActive
            )
        }
    }

    @ViewBuilder
    private func pageFooter(isActive: Bool) -> some View {
        if page.template.footerHeight > 0 || page.footer != nil || isActive {
            headerFooterView(
                content: page.footer,
                slots: footerSlots,
                isActive: isActive
            )
        }
    }

    @ViewBuilder
    private func contentArea(
        sectionBlocks: [Block],
        isActive: Bool,
        contentBodyHeight: CGFloat
    ) -> some View {
        let displayedFootnoteGroups = footnoteDisplayResolver.groups(for: page, document: state.document)

        VStack(spacing: 0) {
            if isActive, hasPageReviewItems {
                reviewDeck
            }

            Group {
                if isActive {
                    activePageContent(sectionBlocks: sectionBlocks)
                } else {
                    HStack(alignment: .top, spacing: page.template.columnSpacing) {
                        ForEach(Array(columnPlacements.enumerated()), id: \.offset) { _, placements in
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(placements) { placement in
                                    if sectionBlocks.indices.contains(placement.blockIndex) {
                                        reviewWrappedView(
                                            for: sectionBlocks[placement.blockIndex].id,
                                            placement: placement
                                        ) {
                                            preview(
                                                for: blockFragmentResolver.block(
                                                    for: sectionBlocks[placement.blockIndex],
                                                    placement: placement
                                                )
                                            )
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: contentBodyHeight, alignment: .topLeading)
            .clipped()

            if !displayedFootnoteGroups.isEmpty {
                Divider()
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(displayedFootnoteGroups) { group in
                        if let title = group.title {
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        ForEach(group.footnotes) { footnote in
                            HStack(alignment: .top, spacing: 6) {
                                Text(footnote.marker)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 24, alignment: .leading)

                                previewText(for: footnote.content, fallbackSize: 11)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func activePageContent(sectionBlocks: [Block]) -> some View {
        if sectionBlocks.isEmpty || page.blockPlacements.isEmpty {
            let pageEditorState = state.richTextState(forPage: page)
            RichTextEditor(
                state: pageEditorState,
                dataSource: state.dataSource(for: page),
                styleSheet: TextStyleSheet.standard
            )
            .onChange(of: pageEditorState.selection) { _, _ in
                state.syncCurrentLocation(using: pageEditorState)
            }
            .onChange(of: pageEditorState.focusedBlockID) { _, _ in
                state.syncCurrentLocation(using: pageEditorState)
            }
        } else {
            HStack(alignment: .top, spacing: page.template.columnSpacing) {
                ForEach(Array(columnPlacements.enumerated()), id: \.offset) { _, placements in
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(placements) { placement in
                            if sectionBlocks.indices.contains(placement.blockIndex) {
                                reviewWrappedView(
                                    for: sectionBlocks[placement.blockIndex].id,
                                    placement: placement
                                ) {
                                    activePlacementView(
                                        for: sectionBlocks[placement.blockIndex],
                                        placement: placement
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func headerFooterView(
        content: HeaderFooter?,
        slots: (HeaderFooterSlot, HeaderFooterSlot, HeaderFooterSlot),
        isActive: Bool
    ) -> some View {
        HStack(spacing: 12) {
            headerFooterColumn(runs: content?.left ?? [], slot: slots.0, alignment: .leading, isActive: isActive)
            headerFooterColumn(runs: content?.center ?? [], slot: slots.1, alignment: .center, isActive: isActive)
            headerFooterColumn(runs: content?.right ?? [], slot: slots.2, alignment: .trailing, isActive: isActive)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func headerFooterColumn(
        runs: [TextRun],
        slot: HeaderFooterSlot,
        alignment: Alignment,
        isActive: Bool
    ) -> some View {
        if isActive {
            let headerFooterState = state.headerFooterRichTextState(for: page.sectionID, slot: slot)
            RichTextEditor(
                state: headerFooterState,
                dataSource: state.headerFooterDataSource(for: page.sectionID, slot: slot),
                styleSheet: TextStyleSheet.standard
            )
            .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 28, alignment: alignment)
            .overlay(alignment: alignment) {
                if runs.isEmpty {
                    Text(slotPlaceholder(for: slot))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .allowsHitTesting(false)
                }
            }
        } else {
            Text(render(runs: runs))
                .frame(maxWidth: .infinity, alignment: alignment)
        }
    }

    private func render(runs: [TextRun]) -> String {
        let resolvedRuns = fieldCodeResolver.resolve(runs: runs, context: fieldContext)
        return resolvedRuns.map(\.text).joined()
    }

    @ViewBuilder
    private func activePlacementView(
        for block: Block,
        placement: BlockFragmentPlacement
    ) -> some View {
        if let replacement = inlineReplacement(for: block, placement: placement) {
            replacement
        } else if canInlineEdit(block: block), usesFragmentEditor(for: placement) {
            fragmentPlacementEditor(placement: placement)
        } else if canInlineEdit(block: block), isEditablePlacement(placement) {
            placementEditor(for: block, placement: placement)
        } else {
            preview(for: blockFragmentResolver.block(for: block, placement: placement))
        }
    }

    private func inlineReplacement(
        for block: Block,
        placement: BlockFragmentPlacement
    ) -> AnyView? {
        pageInlineBlockRenderer?(
            PageInlineBlockContext(
                page: page,
                block: block,
                placement: placement,
                placementCountForBlock: placementCountByBlockID[placement.blockID, default: 0],
                isActivePage: state.currentPage == page.pageNumber && state.currentSection == page.sectionID
            )
        )
    }

    private func canInlineEdit(block: Block) -> Bool {
        switch block.content {
        case .text, .heading, .blockQuote, .codeBlock, .list:
            true
        case .table, .image, .divider, .embed:
            false
        }
    }

    private func isEditablePlacement(_ placement: BlockFragmentPlacement) -> Bool {
        placementCountByBlockID[placement.blockID, default: 0] == 1
    }

    private func usesFragmentEditor(for placement: BlockFragmentPlacement) -> Bool {
        placement.isPartial || placementCountByBlockID[placement.blockID, default: 0] > 1
    }

    @ViewBuilder
    private func fragmentPlacementEditor(
        placement: BlockFragmentPlacement
    ) -> some View {
        let editorState = state.richTextState(forFragment: placement, in: page.sectionID)
        let dataSource = state.dataSource(forFragment: placement, in: page.sectionID)
        let visibleHeight = max(placement.frame.height, 24)

        RichTextEditor(
            state: editorState,
            dataSource: dataSource,
            styleSheet: TextStyleSheet.standard
        )
        .frame(maxWidth: .infinity, minHeight: visibleHeight, maxHeight: visibleHeight, alignment: .topLeading)
        .clipped()
        .overlay(alignment: .topLeading) {
            if showsLeadingContinuation(for: placement) {
                continuationChip(label: "Continued")
                    .padding(.top, 4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsTrailingContinuation(for: placement) {
                continuationChip(label: "Continues")
                    .padding(.bottom, 4)
            }
        }
        .onChange(of: editorState.selection) { _, _ in
            state.syncCurrentLocation(usingFragmentEditor: editorState, sectionID: page.sectionID, placement: placement)
        }
        .onChange(of: editorState.focusedBlockID) { _, _ in
            state.syncCurrentLocation(usingFragmentEditor: editorState, sectionID: page.sectionID, placement: placement)
        }
    }

    @ViewBuilder
    private func placementEditor(
        for block: Block,
        placement: BlockFragmentPlacement
    ) -> some View {
        let editorState = state.richTextState(forBlock: block.id, in: page.sectionID)
        let dataSource = state.dataSource(forBlock: block.id, in: page.sectionID)
        let fullHeight = max(placement.itemHeight, minimumEditorHeight(for: block))
        let visibleHeight = max(placement.frame.height, minimumEditorHeight(for: block))
        let offset = editorOffset(for: placement)

        RichTextEditor(
            state: editorState,
            dataSource: dataSource,
            styleSheet: TextStyleSheet.standard
        )
        .frame(maxWidth: .infinity, minHeight: fullHeight, maxHeight: fullHeight, alignment: .topLeading)
        .offset(y: -offset)
        .frame(maxWidth: .infinity, minHeight: visibleHeight, maxHeight: visibleHeight, alignment: .topLeading)
        .clipped()
        .overlay(alignment: .topLeading) {
            if showsLeadingContinuation(for: placement) {
                continuationChip(label: "Continued")
                    .padding(.top, 4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsTrailingContinuation(for: placement) {
                continuationChip(label: "Continues")
                    .padding(.bottom, 4)
            }
        }
        .onChange(of: editorState.selection) { _, _ in
            state.syncCurrentLocation(using: editorState)
        }
        .onChange(of: editorState.focusedBlockID) { _, _ in
            state.syncCurrentLocation(using: editorState)
        }
    }

    private func minimumEditorHeight(for block: Block) -> CGFloat {
        switch block.content {
        case .heading:
            34
        case .codeBlock:
            56
        default:
            24
        }
    }

    private func editorOffset(for placement: BlockFragmentPlacement) -> CGFloat {
        guard
            placement.isPartial,
            let partialRange = placement.partialRange
        else {
            return 0
        }

        return min(max(partialRange.lowerBound, 0), placement.itemHeight)
    }

    private func showsLeadingContinuation(for placement: BlockFragmentPlacement) -> Bool {
        guard
            placement.isPartial,
            let partialRange = placement.partialRange
        else {
            return false
        }
        return partialRange.lowerBound > 0
    }

    private func showsTrailingContinuation(for placement: BlockFragmentPlacement) -> Bool {
        guard
            placement.isPartial,
            let partialRange = placement.partialRange
        else {
            return false
        }
        return partialRange.upperBound < placement.itemHeight
    }

    private func continuationChip(label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.background.opacity(0.92))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func reviewWrappedView<Content: View>(
        for blockID: BlockID,
        placement: BlockFragmentPlacement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let blockComments = state.comments(for: blockID)
        let blockChanges = state.changes(for: blockID)
        let isCurrentComment = state.isCurrentComment(on: blockID)
        let isCurrentChange = state.isCurrentTrackedChange(on: blockID)
        let tint = reviewTint(
            comments: blockComments,
            changes: blockChanges,
            isCurrentComment: isCurrentComment,
            isCurrentChange: isCurrentChange
        )
        let hasReviewMarkers = !blockComments.isEmpty || !blockChanges.isEmpty

        content()
            .background {
                if hasReviewMarkers {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(isCurrentComment || isCurrentChange ? 0.12 : 0.07))
                        .padding(.horizontal, -6)
                        .padding(.vertical, -4)
                }
            }
            .overlay {
                if hasReviewMarkers {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            tint.opacity(isCurrentComment || isCurrentChange ? 0.55 : 0.24),
                            lineWidth: isCurrentComment || isCurrentChange ? 1.6 : 1
                        )
                        .padding(.horizontal, -6)
                        .padding(.vertical, -4)
                }
            }
            .overlay(alignment: .topTrailing) {
                if hasReviewMarkers, shouldShowReviewBadge(for: placement) {
                    HStack(spacing: 6) {
                        if let comment = blockComments.first {
                            Button {
                                state.focusComment(comment.id)
                            } label: {
                                reviewPill(
                                    systemImage: isCurrentComment ? "text.bubble.fill" : "text.bubble",
                                    label: blockComments.count == 1 ? "1" : "\(blockComments.count)",
                                    tint: .orange
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if let change = blockChanges.first {
                            Button {
                                state.focusChange(change.id)
                            } label: {
                                reviewPill(
                                    systemImage: changeIcon(for: change),
                                    label: blockChanges.count == 1 ? "1" : "\(blockChanges.count)",
                                    tint: changeTint(for: change)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.trailing, 4)
                }
            }
    }

    private func reviewPill(
        systemImage: String,
        label: String,
        tint: Color
    ) -> some View {
        Label(label, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.background.opacity(0.96))
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            }
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func preview(for block: Block) -> some View {
        switch block.content {
        case let .text(content):
            previewText(for: content)
        case let .heading(content, level):
            previewText(
                for: content,
                fallbackSize: headingSize(level: level),
                defaultWeight: .bold
            )
            .padding(.top, level <= 2 ? 8 : 4)
        case let .blockQuote(content):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 4)

                previewText(for: content, fallbackSize: 14)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        case let .codeBlock(code, _):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: code)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        case let .list(content, style, indentLevel):
            HStack(alignment: .top, spacing: 8) {
                Text(listPrefix(for: style))
                    .font(.body.weight(.semibold))
                    .frame(width: 20, alignment: .leading)

                previewText(for: content)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(indentLevel) * 18)
        case let .table(table):
            VStack(alignment: .leading, spacing: 6) {
                if let caption = table.caption {
                    previewText(for: caption, fallbackSize: 12, defaultWeight: .semibold)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                previewText(for: cell, fallbackSize: 13)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .overlay {
                                        Rectangle()
                                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                                    }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        case let .image(content):
            VStack(spacing: 8) {
                imagePreview(for: content)

                if let altText = content.altText, !altText.isEmpty {
                    Text(altText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .divider:
            Divider()
                .padding(.vertical, 8)
        case let .embed(embed):
            VStack(alignment: .leading, spacing: 6) {
                Text(embed.kind.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(embed.payload ?? "[Embedded content]")
                    .font(.body)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func previewText(
        for content: TextContent,
        fallbackSize: CGFloat = 14,
        defaultWeight: Font.Weight = .regular,
        defaultDesign: Font.Design = .default
    ) -> Text {
        let resolved = resolvedTextContent(content)
        return resolved.runs.reduce(Text("")) { partial, run in
            partial + previewText(
                for: run,
                fallbackSize: fallbackSize,
                defaultWeight: defaultWeight,
                defaultDesign: defaultDesign
            )
        }
    }

    private func previewText(
        for run: TextRun,
        fallbackSize: CGFloat,
        defaultWeight: Font.Weight,
        defaultDesign: Font.Design
    ) -> Text {
        let size = run.attributes.fontSize ?? fallbackSize
        let design: Font.Design = run.attributes.code ? .monospaced : defaultDesign

        let font: Font = if let family = run.attributes.fontFamily, !family.isEmpty {
            .custom(family, size: size)
        } else {
            .system(size: size, weight: run.attributes.bold ? .bold : defaultWeight, design: design)
        }

        var text = Text(verbatim: run.text).font(font)

        if run.attributes.bold {
            text = text.bold()
        }
        if run.attributes.italic {
            text = text.italic()
        }
        if run.attributes.underline || run.attributes.link != nil {
            text = text.underline()
        }
        if run.attributes.strikethrough {
            text = text.strikethrough()
        }
        if let color = run.attributes.color {
            text = text.foregroundColor(color.swiftUIColor)
        } else if run.attributes.link != nil {
            text = text.foregroundColor(.blue)
        }

        return text
    }

    private func resolvedTextContent(_ content: TextContent) -> TextContent {
        TextContent(runs: fieldCodeResolver.resolve(runs: content.runs, context: fieldContext))
    }

    @ViewBuilder
    private func imagePreview(for content: ImageContent) -> some View {
        let previewHeight = min(content.size?.height ?? 180, 240)

        if let image = resolvedImage(from: content) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if let url = content.url {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    placeholderImagePreview(height: previewHeight, label: "Image unavailable")
                case .empty:
                    placeholderImagePreview(height: previewHeight, label: "Loading image...")
                @unknown default:
                    placeholderImagePreview(height: previewHeight, label: nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            placeholderImagePreview(height: previewHeight, label: nil)
        }
    }

    @ViewBuilder
    private func placeholderImagePreview(height: CGFloat, label: String?) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(
                colors: [Color.secondary.opacity(0.14), Color.secondary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(height: height)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    if let label {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
    }

    private func resolvedImage(from content: ImageContent) -> Image? {
        guard let data = content.data else { return nil }

        #if canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #elseif canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }

    private func headingSize(level: Int) -> CGFloat {
        switch level {
        case 1: 28
        case 2: 24
        case 3: 20
        case 4: 18
        case 5: 16
        default: 15
        }
    }

    private func listPrefix(for style: RichTextPrimitive.ListStyle) -> String {
        switch style {
        case .bullet:
            "•"
        case .numbered:
            "1."
        case .checklist:
            "□"
        }
    }

    private func slotPlaceholder(for slot: HeaderFooterSlot) -> String {
        switch slot {
        case .firstHeaderLeft:
            "First header left"
        case .firstHeaderCenter:
            "First header center"
        case .firstHeaderRight:
            "First header right"
        case .headerLeft:
            "Header left"
        case .headerCenter:
            "Header center"
        case .headerRight:
            "Header right"
        case .firstFooterLeft:
            "First footer left"
        case .firstFooterCenter:
            "First footer center"
        case .firstFooterRight:
            "First footer right"
        case .footerLeft:
            "Footer left"
        case .footerCenter:
            "Footer center"
        case .footerRight:
            "Footer right"
        case .evenHeaderLeft:
            "Even header left"
        case .evenHeaderCenter:
            "Even header center"
        case .evenHeaderRight:
            "Even header right"
        case .evenFooterLeft:
            "Even footer left"
        case .evenFooterCenter:
            "Even footer center"
        case .evenFooterRight:
            "Even footer right"
        }
    }

    private var isFirstPageInSection: Bool {
        state.layoutEngine.pages.first(where: { $0.sectionID == page.sectionID })?.pageNumber == page.pageNumber
    }

    private var usesFirstHeaderFooterSlots: Bool {
        guard let config = state.document.section(page.sectionID)?.headerFooter else { return false }
        return config.differentFirstPage && isFirstPageInSection
    }

    private var usesEvenHeaderFooterSlots: Bool {
        guard let config = state.document.section(page.sectionID)?.headerFooter else { return false }
        return !usesFirstHeaderFooterSlots && config.differentOddEven && page.pageNumber.isMultiple(of: 2)
    }

    private var headerSlots: (HeaderFooterSlot, HeaderFooterSlot, HeaderFooterSlot) {
        if usesFirstHeaderFooterSlots {
            return (.firstHeaderLeft, .firstHeaderCenter, .firstHeaderRight)
        }
        if usesEvenHeaderFooterSlots {
            return (.evenHeaderLeft, .evenHeaderCenter, .evenHeaderRight)
        }
        return (.headerLeft, .headerCenter, .headerRight)
    }

    private var footerSlots: (HeaderFooterSlot, HeaderFooterSlot, HeaderFooterSlot) {
        if usesFirstHeaderFooterSlots {
            return (.firstFooterLeft, .firstFooterCenter, .firstFooterRight)
        }
        if usesEvenHeaderFooterSlots {
            return (.evenFooterLeft, .evenFooterCenter, .evenFooterRight)
        }
        return (.footerLeft, .footerCenter, .footerRight)
    }

    private var footnoteAreaHeight: CGFloat {
        guard !page.footnotes.isEmpty else { return 0 }

        let estimatedHeight = page.footnotes.reduce(CGFloat(18)) { partialResult, footnote in
            let lines = max(Int(ceil(Double(max(footnote.content.plainText.count, 1)) / 44.0)), 1)
            return partialResult + CGFloat(lines) * 14 + 6
        }

        return min(estimatedHeight, page.template.contentHeight * 0.4)
    }

    private var fieldContext: FieldResolutionContext {
        FieldResolutionContext(
            pageNumber: page.pageNumber,
            pageCount: state.layoutEngine.pages.count,
            sectionNumber: (state.document.sectionIndex(page.sectionID) ?? 0) + 1,
            date: state.document.settings.modifiedAt ?? state.document.settings.createdAt ?? Date(),
            title: state.document.title,
            author: state.document.settings.author
        )
    }

    private var placementCountByBlockID: [BlockID: Int] {
        page.blockPlacements.reduce(into: [BlockID: Int]()) { counts, placement in
            counts[placement.blockID, default: 0] += 1
        }
    }

    private var firstPlacementIDByBlockID: [BlockID: UUID] {
        columnPlacements
            .flatMap { $0 }
            .reduce(into: [BlockID: UUID]()) { partialResult, placement in
                partialResult[placement.blockID] = partialResult[placement.blockID] ?? placement.id
            }
    }

    private var columnPlacements: [[BlockFragmentPlacement]] {
        let columnCount = max(page.template.columns, 1)
        guard columnCount > 1 else { return [page.blockPlacements] }

        let columnWidthWithSpacing = max(page.template.columnWidth + page.template.columnSpacing, 1)
        var columns = Array(repeating: [BlockFragmentPlacement](), count: columnCount)

        for placement in page.blockPlacements {
            let rawColumn = Int((placement.frame.minX / columnWidthWithSpacing).rounded(.down))
            let columnIndex = min(max(rawColumn, 0), columnCount - 1)
            columns[columnIndex].append(placement)
        }

        return columns.map { placements in
            placements.sorted {
                if $0.frame.minY == $1.frame.minY {
                    return $0.frame.minX < $1.frame.minX
                }
                return $0.frame.minY < $1.frame.minY
            }
        }
    }

    private var hasPageReviewItems: Bool {
        pageReviewComment != nil || pageReviewChange != nil
    }

    @ViewBuilder
    private var reviewDeck: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                if let comment = pageReviewComment {
                    commentReviewCard(comment)
                }
                if let change = pageReviewChange {
                    trackedChangeReviewCard(change)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if let comment = pageReviewComment {
                    commentReviewCard(comment)
                }
                if let change = pageReviewChange {
                    trackedChangeReviewCard(change)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func commentReviewCard(_ comment: Comment) -> some View {
        let isFocused = state.currentComment?.id == comment.id
        let bodyDraft = commentBodyBinding(for: comment)
        let replyDraft = replyBodyBinding(for: comment)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(comment.status == .open ? "Comment" : "Resolved Comment", systemImage: "text.bubble.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Spacer(minLength: 0)

                if isFocused {
                    Text("Focused")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            TextField("Edit comment", text: bodyDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2 ... 4)

            if commentBodyDraft(for: comment) != comment.body {
                HStack(spacing: 8) {
                    Button("Save") {
                        saveCommentEdits(comment)
                    }
                    .buttonStyle(.borderless)

                    Button("Reset") {
                        discardCommentEdits(comment)
                    }
                    .buttonStyle(.borderless)

                    Spacer(minLength: 0)
                }
                .font(.caption)
            }

            if !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(comment.replies) { reply in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reply.author.rawValue)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(reply.body)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            if comment.status == .open {
                TextField("Reply", text: replyDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1 ... 3)

                HStack(spacing: 8) {
                    Button("Reply") {
                        sendReply(for: comment)
                    }
                    .buttonStyle(.borderless)
                    .disabled(replyBodyDraft(for: comment).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer(minLength: 0)
                }
                .font(.caption)
            }

            HStack(spacing: 8) {
                Button("Open") {
                    state.focusComment(comment.id)
                }
                .buttonStyle(.borderless)

                Button("Prev") {
                    state.goToPreviousComment()
                }
                .buttonStyle(.borderless)
                .disabled(state.commentStore.comments.isEmpty)

                Button("Next") {
                    state.goToNextComment()
                }
                .buttonStyle(.borderless)
                .disabled(state.commentStore.comments.isEmpty)

                Spacer(minLength: 0)

                if comment.status == .open {
                    Button("Resolve") {
                        state.focusComment(comment.id)
                        state.resolveCurrentComment()
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button("Reopen") {
                        state.focusComment(comment.id)
                        state.reopenCurrentComment()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func trackedChangeReviewCard(_ change: TrackedChange) -> some View {
        let tint = changeTint(for: change)
        let isFocused = state.currentTrackedChange?.id == change.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Tracked Change", systemImage: changeIcon(for: change))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer(minLength: 0)

                if isFocused {
                    Text("Focused")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }

            Text(changeSummary(change))
                .font(.footnote)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button("Open") {
                    state.focusChange(change.id)
                }
                .buttonStyle(.borderless)

                Button("Prev") {
                    state.goToPreviousChange()
                }
                .buttonStyle(.borderless)
                .disabled(state.changeTracker.visibleChanges.isEmpty)

                Button("Next") {
                    state.goToNextChange()
                }
                .buttonStyle(.borderless)
                .disabled(state.changeTracker.visibleChanges.isEmpty)

                Spacer(minLength: 0)

                Button("Accept") {
                    state.focusChange(change.id)
                    state.acceptCurrentChange()
                }
                .buttonStyle(.borderless)

                Button("Reject", role: .destructive) {
                    state.focusChange(change.id)
                    state.rejectCurrentChange()
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var pageReviewComment: Comment? {
        let comments = state.comments(on: page)
        guard !comments.isEmpty else { return nil }

        if let current = state.currentComment,
           comments.contains(where: { $0.id == current.id }) {
            return current
        }

        return comments.first(where: { $0.status == .open }) ?? comments.first
    }

    private var pageReviewChange: TrackedChange? {
        let changes = state.changes(on: page)
        guard !changes.isEmpty else { return nil }

        if let current = state.currentTrackedChange,
           changes.contains(where: { $0.id == current.id }) {
            return current
        }

        return changes.first
    }

    private var pageAnnotations: [PageAnnotation] {
        let bookmarks = state.bookmarks(on: page).map { bookmark in
            PageAnnotation(
                title: bookmark.name,
                icon: "bookmark.fill",
                tint: .blue,
                action: { state.focusBookmark(bookmark.id) }
            )
        }
        let commentAnnotations = state.comments(on: page)
            .filter { $0.status == .open }
            .map { comment in
                PageAnnotation(
                    title: comment.body,
                    icon: "text.bubble.fill",
                    tint: .orange,
                    action: { state.focusComment(comment.id) }
                )
            }
        let changeAnnotations = trackedChangeAnnotations

        return Array((bookmarks + commentAnnotations + changeAnnotations).prefix(6))
    }

    private var trackedChangeAnnotations: [PageAnnotation] {
        let changes = state.changes(on: page)
        guard !changes.isEmpty else { return [] }

        let insertions = changes.filter {
            if case .insertion = $0.type { return true }
            return false
        }.count
        let deletions = changes.filter {
            if case .deletion = $0.type { return true }
            return false
        }.count
        let formatChanges = changes.filter {
            if case .formatChange = $0.type { return true }
            return false
        }.count

        var annotations: [PageAnnotation] = []
        if insertions > 0 {
            annotations.append(
                PageAnnotation(
                    title: insertions == 1 ? "1 insertion" : "\(insertions) insertions",
                    icon: "plus.circle.fill",
                    tint: .green,
                    action: { state.focusFirstChange(on: page) }
                )
            )
        }
        if deletions > 0 {
            annotations.append(
                PageAnnotation(
                    title: deletions == 1 ? "1 deletion" : "\(deletions) deletions",
                    icon: "minus.circle.fill",
                    tint: .red,
                    action: { state.focusFirstChange(on: page) }
                )
            )
        }
        if formatChanges > 0 {
            annotations.append(
                PageAnnotation(
                    title: formatChanges == 1 ? "1 format change" : "\(formatChanges) format changes",
                    icon: "paintbrush.fill",
                    tint: .teal,
                    action: { state.focusFirstChange(on: page) }
                )
            )
        }

        return annotations
    }

    private func annotationBadge(_ annotation: PageAnnotation) -> some View {
        Group {
            if let action = annotation.action {
                Button(action: action) {
                    annotationBadgeLabel(annotation)
                }
                .buttonStyle(.plain)
            } else {
                annotationBadgeLabel(annotation)
            }
        }
        .frame(maxWidth: 180, alignment: .trailing)
    }

    private func annotationBadgeLabel(_ annotation: PageAnnotation) -> some View {
        Label(annotation.title, systemImage: annotation.icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(annotation.tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(annotation.tint.opacity(0.1))
            .clipShape(Capsule())
    }

    private func shouldShowReviewBadge(for placement: BlockFragmentPlacement) -> Bool {
        firstPlacementIDByBlockID[placement.blockID] == placement.id
    }

    private func reviewTint(
        comments: [Comment],
        changes: [TrackedChange],
        isCurrentComment: Bool,
        isCurrentChange: Bool
    ) -> Color {
        if isCurrentComment {
            return .orange
        }
        if isCurrentChange, let currentTrackedChange = state.currentTrackedChange {
            return changeTint(for: currentTrackedChange)
        }
        if !comments.isEmpty && changes.isEmpty {
            return .orange
        }
        if comments.isEmpty, let firstChange = changes.first {
            return changeTint(for: firstChange)
        }
        return .secondary
    }

    private func changeTint(for change: TrackedChange) -> Color {
        switch change.type {
        case .insertion:
            return .green
        case .deletion:
            return .red
        case .formatChange:
            return .teal
        }
    }

    private func changeIcon(for change: TrackedChange) -> String {
        switch change.type {
        case .insertion:
            return "plus.circle.fill"
        case .deletion:
            return "minus.circle.fill"
        case .formatChange:
            return "paintbrush.fill"
        }
    }

    private func changeSummary(_ change: TrackedChange) -> String {
        if let context = state.trackedChangeContexts[change.id] {
            switch context.operation {
            case let .insert(blocks, _):
                return structuralReviewSummary(
                    count: blocks.count,
                    singular: "Inserted block",
                    plural: "Inserted blocks",
                    preview: changePreviewText(change)
                )
            case let .delete(blocks, _):
                return structuralReviewSummary(
                    count: blocks.count,
                    singular: "Deleted block",
                    plural: "Deleted blocks",
                    preview: changePreviewText(change)
                )
            case .replace:
                break
            }
        }

        switch change.type {
        case let .insertion(text):
            return trimmedPreview(for: text, fallback: "Insertion")
        case let .deletion(text):
            return trimmedPreview(for: text, fallback: "Deletion")
        case .formatChange:
            return "Formatting change"
        }
    }

    private func commentSummary(_ body: String) -> String {
        trimmedPreview(for: body, fallback: "Untitled comment")
    }

    private func trimmedPreview(for text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(72))
    }

    private func changePreviewText(_ change: TrackedChange) -> String {
        switch change.type {
        case let .insertion(text), let .deletion(text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .formatChange:
            return ""
        }
    }

    private func structuralReviewSummary(
        count: Int,
        singular: String,
        plural: String,
        preview: String
    ) -> String {
        let title = count == 1 ? singular : "\(count) \(plural.lowercased())"
        guard !preview.isEmpty else { return title }
        return "\(title): \(String(preview.prefix(72)))"
    }

    private func commentBodyBinding(for comment: Comment) -> Binding<String> {
        Binding(
            get: { commentBodyDraft(for: comment) },
            set: { commentDrafts[comment.id] = $0 }
        )
    }

    private func replyBodyBinding(for comment: Comment) -> Binding<String> {
        Binding(
            get: { replyBodyDraft(for: comment) },
            set: { replyDrafts[comment.id] = $0 }
        )
    }

    private func commentBodyDraft(for comment: Comment) -> String {
        commentDrafts[comment.id] ?? comment.body
    }

    private func replyBodyDraft(for comment: Comment) -> String {
        replyDrafts[comment.id] ?? ""
    }

    private func discardCommentEdits(_ comment: Comment) {
        commentDrafts.removeValue(forKey: comment.id)
    }

    private func saveCommentEdits(_ comment: Comment) {
        let draft = commentBodyDraft(for: comment)
        state.updateComment(comment.id, body: draft)
        commentDrafts[comment.id] = draft
    }

    private func sendReply(for comment: Comment) {
        let draft = replyBodyDraft(for: comment)
        state.reply(to: comment.id, body: draft, authorID: reviewAuthorID)
        replyDrafts[comment.id] = ""
    }

    private var reviewAuthorID: String {
        let trackerAuthor = state.changeTracker.currentAuthor.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trackerAuthor.isEmpty {
            return trackerAuthor
        }

        if let documentAuthor = state.document.settings.author?.trimmingCharacters(in: .whitespacesAndNewlines),
           !documentAuthor.isEmpty {
            return documentAuthor
        }

        return "system"
    }
}

private struct PageAnnotation: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let action: (() -> Void)?
}
