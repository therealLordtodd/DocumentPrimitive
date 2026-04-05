import Foundation
import RichTextPrimitive
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct PageView: View {
    @Bindable private var state: DocumentEditorState
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
            Text("Page \(page.pageNumber)")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
            Group {
                if isActive {
                    activePageContent(sectionBlocks: sectionBlocks)
                } else {
                    HStack(alignment: .top, spacing: page.template.columnSpacing) {
                        ForEach(Array(columnPlacements.enumerated()), id: \.offset) { _, placements in
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(placements) { placement in
                                    if sectionBlocks.indices.contains(placement.blockIndex) {
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
                                activePlacementView(
                                    for: sectionBlocks[placement.blockIndex],
                                    placement: placement
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
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
        if canInlineEdit(block: block), isEditablePlacement(placement) {
            placementEditor(for: block, placement: placement)
        } else {
            preview(for: blockFragmentResolver.block(for: block, placement: placement))
        }
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
}
