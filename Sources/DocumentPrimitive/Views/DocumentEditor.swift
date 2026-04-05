import RichTextPrimitive
import SwiftUI

public struct DocumentEditor: View {
    @Bindable private var state: DocumentEditorState

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            DocumentToolbar(state: state)

            if state.showRuler {
                rulerView
            }

            contentView
        }
        .onAppear {
            state.layoutEngine.reflow()
            state.syncCurrentLocationToSelection()
        }
        .onChange(of: state.richTextState.selection) { _, _ in
            state.syncCurrentLocationToSelection()
        }
        .onChange(of: state.richTextState.focusedBlockID) { _, _ in
            state.syncCurrentLocationToSelection()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch state.viewMode {
        case .page:
            PrintPreview(state: state)
        case .continuous, .canvas:
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(state.document.sections) { section in
                        RichTextEditor(
                            state: state.richTextState,
                            dataSource: state.dataSource(for: section.id),
                            styleSheet: TextStyleSheet.standard
                        )
                        .frame(minHeight: 220)
                        .padding()
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
                    }
                }
                .padding(24)
            }
            .background(Color.secondary.opacity(0.05))
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
