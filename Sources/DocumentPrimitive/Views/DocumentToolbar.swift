import SwiftUI

public struct DocumentToolbar: View {
    @Bindable private var state: DocumentEditorState

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 12) {
            Picker("View", selection: $state.viewMode) {
                Text("Page").tag(DocumentViewMode.page)
                Text("Continuous").tag(DocumentViewMode.continuous)
                Text("Canvas").tag(DocumentViewMode.canvas)
            }
            .pickerStyle(.segmented)

            Toggle("Ruler", isOn: $state.showRuler)
            Toggle("Formatting", isOn: $state.showFormatting)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    state.goToPreviousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToPreviousPage)

                Text("Page \(state.currentPage)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    state.goToNextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToNextPage)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
