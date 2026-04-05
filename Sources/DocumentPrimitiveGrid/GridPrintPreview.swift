#if canImport(GridPrimitive) && canImport(GridPrimitiveTable)
import DocumentPrimitive
import Foundation
import SwiftUI

@MainActor
public struct GridDocumentEditor: View {
    @Bindable private var state: DocumentEditorState

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
                            .fill(index.isMultiple(of: 4) ? Color.secondary : Color.secondary.opacity(0.5))
                            .frame(width: 1, height: index.isMultiple(of: 4) ? 14 : 8)
                        if index < tickCount, index.isMultiple(of: 4) {
                            Text("\(index / 4)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 28)
        .background(Color.secondary.opacity(0.08))
    }
}

@MainActor
public struct GridPrintPreview: View {
    @Bindable private var state: DocumentEditorState

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 28) {
                    ForEach(state.layoutEngine.pages) { page in
                        GridPageView(state: state, page: page)
                            .id(pageScrollID(for: page))
                    }
                }
                .padding(24)
            }
            .background(Color.secondary.opacity(0.08))
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
        withAnimation(.easeInOut(duration: 0.2)) {
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
    private let page: ComputedPage
    private let tableResolver = GridPageTableResolver()

    public init(state: DocumentEditorState, page: ComputedPage) {
        self.state = state
        self.page = page
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageView(state: state, page: page)

            if isActivePage, !tablePlacements.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tablePlacements.count == 1 ? "Table On This Page" : "Tables On This Page")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(tablePlacements) { placement in
                        VStack(alignment: .leading, spacing: 8) {
                            if case let .table(table) = placement.block.content,
                               let caption = table.caption?.plainText,
                               !caption.isEmpty {
                                Text(caption)
                                    .font(.footnote.weight(.semibold))
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
                        .padding(14)
                        .background(Color.secondary.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
}
#endif
