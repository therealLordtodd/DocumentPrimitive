import RichTextPrimitive
import SwiftUI

public struct PageView: View {
    @Bindable private var state: DocumentEditorState
    private let page: ComputedPage
    private let fieldCodeResolver = FieldCodeResolver()

    public init(state: DocumentEditorState, page: ComputedPage) {
        self.state = state
        self.page = page
    }

    public var body: some View {
        let section = state.document.section(page.sectionID)
        let sectionBlocks = section?.blocks ?? []
        let visibleBlocks: [Block] = page.blockRanges.reduce(into: []) { partialResult, range in
            guard !sectionBlocks.isEmpty else { return }
            let start = min(max(range.startIndex, 0), sectionBlocks.count - 1)
            let end = min(max(range.endIndex, start), sectionBlocks.count - 1)
            partialResult.append(contentsOf: sectionBlocks[start...end])
        }
        let isActivePage = state.currentPage == page.pageNumber && state.currentSection == page.sectionID
        let footnoteHeight = footnoteAreaHeight
        let contentBodyHeight = max(page.template.contentHeight - footnoteHeight, 120)

        VStack(spacing: 0) {
            pageHeader(isActive: isActivePage)
                .frame(width: page.template.contentWidth, height: page.template.headerHeight, alignment: .bottom)
                .padding(.top, page.template.margins.top)

            contentArea(visibleBlocks: visibleBlocks, isActive: isActivePage, contentBodyHeight: contentBodyHeight)
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
                slots: (.headerLeft, .headerCenter, .headerRight),
                isActive: isActive
            )
        }
    }

    @ViewBuilder
    private func pageFooter(isActive: Bool) -> some View {
        if page.template.footerHeight > 0 || page.footer != nil || isActive {
            headerFooterView(
                content: page.footer,
                slots: (.footerLeft, .footerCenter, .footerRight),
                isActive: isActive
            )
        }
    }

    @ViewBuilder
    private func contentArea(
        visibleBlocks: [Block],
        isActive: Bool,
        contentBodyHeight: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            Group {
                if isActive {
                    RichTextEditor(
                        state: state.richTextState,
                        dataSource: state.dataSource(for: page),
                        styleSheet: TextStyleSheet.standard
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(visibleBlocks) { block in
                            preview(for: block)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: contentBodyHeight, alignment: .topLeading)
            .clipped()

            if !page.footnotes.isEmpty {
                Divider()
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(page.footnotes) { footnote in
                        previewText(for: footnote.content, fallbackSize: 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
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
            RichTextEditor(
                state: state.richTextState,
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
        case let .image(content):
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.secondary.opacity(0.14), Color.secondary.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: min(content.size?.height ?? 180, 240))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }

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
        case .headerLeft:
            "Header left"
        case .headerCenter:
            "Header center"
        case .headerRight:
            "Header right"
        case .footerLeft:
            "Footer left"
        case .footerCenter:
            "Footer center"
        case .footerRight:
            "Footer right"
        }
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
}
