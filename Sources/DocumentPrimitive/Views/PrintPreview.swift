import SwiftUI

public struct PrintPreview: View {
    @Bindable private var state: DocumentEditorState

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 28) {
                    ForEach(state.layoutEngine.pages) { page in
                        PageView(state: state, page: page)
                            .id(state.pageScrollKey(for: page))
                    }
                }
                .padding(24)
            }
            .background(Color.secondary.opacity(0.08))
            .onAppear {
                scrollToCurrentPage(using: proxy)
            }
            .onChange(of: state.currentPageScrollKey) { _, _ in
                scrollToCurrentPage(using: proxy)
            }
        }
    }

    private func scrollToCurrentPage(using proxy: ScrollViewProxy) {
        guard let target = state.currentPageScrollKey else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}
