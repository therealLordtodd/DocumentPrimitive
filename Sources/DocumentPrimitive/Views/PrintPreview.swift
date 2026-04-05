import SwiftUI

public struct PrintPreview: View {
    @Bindable private var state: DocumentEditorState

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 28) {
                ForEach(state.layoutEngine.pages) { page in
                    PageView(state: state, page: page)
                }
            }
            .padding(24)
        }
        .background(Color.secondary.opacity(0.08))
    }
}
