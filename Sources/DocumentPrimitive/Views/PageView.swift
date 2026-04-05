import RichTextPrimitive
import SwiftUI

public struct PageView: View {
    @Bindable private var state: DocumentEditorState
    private let page: ComputedPage

    public init(state: DocumentEditorState, page: ComputedPage) {
        self.state = state
        self.page = page
    }

    public var body: some View {
        let section = state.document.section(page.sectionID)
        let pageSetup = section?.pageSetup ?? state.document.settings.defaultPageSetup
        let sectionBlocks = section?.blocks ?? []
        let visibleBlocks: [Block] = page.blockRanges.reduce(into: []) { partialResult, range in
            guard !sectionBlocks.isEmpty else { return }
            let start = min(max(range.startIndex, 0), sectionBlocks.count - 1)
            let end = min(max(range.endIndex, start), sectionBlocks.count - 1)
            partialResult.append(contentsOf: sectionBlocks[start...end])
        }

        VStack(spacing: 0) {
            headerFooterView(page.header)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 24)

            Divider()
                .padding(.top, 8)

            Group {
                if state.currentPage == page.pageNumber {
                    RichTextEditor(
                        state: state.richTextState,
                        dataSource: state.dataSource(for: page.sectionID),
                        styleSheet: TextStyleSheet.standard
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(visibleBlocks) { block in
                                Text(block.content.textContent?.plainText ?? block.type.rawValue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !page.footnotes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(page.footnotes) { footnote in
                        Text(footnote.content.plainText)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
            }

            Divider()

            headerFooterView(page.footer)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .frame(
            width: min(pageSetup.canvasSize.width, 700),
            height: min(pageSetup.canvasSize.height, 900)
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
    private func headerFooterView(_ content: HeaderFooter?) -> some View {
        HStack {
            Text(render(runs: content?.left ?? []))
            Spacer()
            Text(render(runs: content?.center ?? []))
            Spacer()
            Text(render(runs: content?.right ?? []))
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func render(runs: [TextRun]) -> String {
        runs.map(\.text).joined()
    }
}
