import SwiftUI

public struct PrintPreview: View {
    @Bindable private var state: DocumentEditorState

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        let projection = state.reviewDisplayProjection

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 28) {
                    ForEach(projection.pages) { page in
                        PageView(
                            state: state,
                            page: page,
                            documentOverride: projection.document,
                            pagesOverride: projection.pages,
                            readOnlyOverride: projection.isReadOnly
                        )
                            .id(state.pageScrollKey(for: page))
                    }
                }
                .padding(24)
            }
            .background(Color.secondary.opacity(0.08))
            .onAppear {
                scrollToCurrentPage(using: proxy, pages: projection.pages)
            }
            .onChange(of: state.currentPageScrollKey(in: projection.pages)) { _, _ in
                scrollToCurrentPage(using: proxy, pages: projection.pages)
            }
        }
    }

    private func scrollToCurrentPage(using proxy: ScrollViewProxy, pages: [ComputedPage]) {
        guard let target = state.currentPageScrollKey(in: pages) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}
