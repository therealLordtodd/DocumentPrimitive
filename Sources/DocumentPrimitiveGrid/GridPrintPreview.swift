#if canImport(GridPrimitive) && canImport(GridPrimitiveTable)
import DocumentPrimitive
import Foundation
import RichTextPrimitive
import SwiftUI

@MainActor
public struct GridDocumentEditor: View {
    @Bindable private var state: DocumentEditorState
    @Environment(\.documentTheme) private var theme

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        switch state.viewMode {
        case .page:
            VStack(spacing: 0) {
                DocumentToolbar(state: state)

                if state.showRuler {
                    rulerView
                }

                GridPrintPreview(state: state)
            }
            .onAppear {
                state.layoutEngine.reflow()
            }
        case .continuous, .canvas:
            DocumentEditor(state: state)
        }
    }

    private var rulerView: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let tickCount = max(Int(width / 24), 1)

            HStack(spacing: 0) {
                ForEach(0...tickCount, id: \.self) { index in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(index.isMultiple(of: 4) ? theme.colors.secondary : theme.colors.secondary.opacity(theme.opacity.rulerTickMinor + 0.05))
                            .frame(width: 1, height: index.isMultiple(of: 4) ? 14 : 8)
                        if index < tickCount, index.isMultiple(of: 4) {
                            Text("\(index / 4)")
                                .font(theme.typography.caption2)
                                .foregroundStyle(theme.colors.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, theme.spacing.containerPadding - 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: theme.metrics.rulerHeight - 6)
        .background(theme.mutedFill)
    }
}

@MainActor
public struct GridPrintPreview: View {
    @Bindable private var state: DocumentEditorState
    @Environment(\.documentTheme) private var theme

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacing.pageGap) {
                    ForEach(state.layoutEngine.pages) { page in
                        GridPageView(state: state, page: page)
                            .id(pageScrollID(for: page))
                    }
                }
                .padding(theme.spacing.containerPadding)
            }
            .background(theme.colors.canvasBackground)
            .onAppear {
                scrollToCurrentPage(using: proxy)
            }
            .onChange(of: currentPageScrollID) { _, _ in
                scrollToCurrentPage(using: proxy)
            }
        }
    }

    private func scrollToCurrentPage(using proxy: ScrollViewProxy) {
        guard let target = currentPageScrollID else { return }
        withAnimation(theme.scrollAnimation) {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func pageScrollID(for page: ComputedPage) -> String {
        "\(page.sectionID.rawValue)#\(page.pageNumber)"
    }

    private var currentPageScrollID: String? {
        if let sectionID = state.currentSection,
           let exact = state.layoutEngine.pages.first(where: {
               $0.sectionID == sectionID && $0.pageNumber == state.currentPage
           }) {
            return pageScrollID(for: exact)
        }

        if let sectionID = state.currentSection,
           let sameSection = state.layoutEngine.pages.first(where: { $0.sectionID == sectionID }) {
            return pageScrollID(for: sameSection)
        }

        if let samePageNumber = state.layoutEngine.pages.first(where: { $0.pageNumber == state.currentPage }) {
            return pageScrollID(for: samePageNumber)
        }

        guard let firstPage = state.layoutEngine.pages.first else { return nil }
        return pageScrollID(for: firstPage)
    }
}

@MainActor
public struct GridPageView: View {
    @Bindable private var state: DocumentEditorState
    @Environment(\.documentTheme) private var theme
    private let page: ComputedPage
    private let tableResolver = GridPageTableResolver()

    public init(state: DocumentEditorState, page: ComputedPage) {
        self.state = state
        self.page = page
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap - 4) {
            PageView(state: state, page: page)
                .pageInlineBlockRenderer(pageInlineRenderer)

            if isActivePage, !detachedTablePlacements.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.navigatorRowPadding) {
                    Text(detachedTablePlacements.count == 1 ? "Table Editor" : "Table Editors")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.secondary)

                    ForEach(detachedTablePlacements) { placement in
                        VStack(alignment: .leading, spacing: theme.spacing.navigatorRowSpacing) {
                            if case let .table(table) = placement.block.content,
                               let caption = table.caption?.plainText,
                               !caption.isEmpty {
                                Text(caption)
                                    .font(theme.typography.footnote.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }

                            DocumentTableBlockEditor(
                                editorState: state,
                                sectionID: placement.sectionID,
                                blockID: placement.block.id,
                                editable: true,
                                configuration: .compact
                            )
                        }
                        .padding(theme.spacing.gridTableEditorPadding)
                        .background(theme.colors.secondary.opacity(theme.opacity.mutedFill + 0.01))
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.gridTableEditorCornerRadius, style: .continuous))
                    }
                }
                .frame(maxWidth: page.template.size.width, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var isActivePage: Bool {
        state.currentPage == page.pageNumber && state.currentSection == page.sectionID
    }

    private var tablePlacements: [GridPageTablePlacement] {
        tableResolver.tablePlacements(on: page, in: state.document)
    }

    private var detachedTablePlacements: [GridPageTablePlacement] {
        tablePlacements.filter { !$0.supportsInlineEditing }
    }

    private var inlineEditableTableIDs: Set<BlockID> {
        Set(tablePlacements.filter(\.supportsInlineEditing).map(\.block.id))
    }

    private var pageInlineRenderer: PageInlineBlockRenderer {
        PageInlineBlockRenderer { context in
            guard
                context.isActivePage,
                inlineEditableTableIDs.contains(context.block.id),
                context.placementCountForBlock == 1,
                case .table = context.block.content
            else {
                return nil
            }

            return AnyView(
                DocumentTableBlockEditor(
                    editorState: state,
                    sectionID: context.page.sectionID,
                    blockID: context.block.id,
                    editable: true,
                    configuration: .compact
                )
                .padding(theme.spacing.navigatorRowSpacing)
                .frame(
                    maxWidth: .infinity,
                    minHeight: max(context.placement.frame.height, 84),
                    maxHeight: max(context.placement.frame.height, 84),
                    alignment: .topLeading
                )
                .background(theme.colors.secondary.opacity(theme.opacity.mutedFill + 0.01))
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius, style: .continuous))
            )
        }
    }
}
#endif
