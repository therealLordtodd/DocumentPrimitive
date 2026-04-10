import SwiftUI

@MainActor
struct DocumentSearchPopover: View {
    @Bindable private var state: DocumentEditorState
    @State private var searchResults = DocumentSearchNavigatorResults(items: [], totalCount: 0, facetCounts: [:])
    @State private var isSearching = false

    init(state: DocumentEditorState) {
        self._state = Bindable(wrappedValue: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            TextField("Search headings, comments, bookmarks, and changes", text: $state.documentSearchText)
                .textFieldStyle(.roundedBorder)

            scopeChips

            Divider()

            if isSearching {
                ProgressView("Searching document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if searchResults.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(searchResults.items) { item in
                            resultRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(width: 430, height: 520)
        .task(id: refreshToken) {
            await refreshResults()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Search Document")
                    .font(.headline)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !state.documentSearchText.isEmpty || state.selectedDocumentSearchScope != nil {
                Button("Reset") {
                    state.documentSearchText = ""
                    state.selectedDocumentSearchScope = nil
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                scopeChip(scope: nil, label: "All", count: totalFacetCount)
                ForEach(DocumentSearchScope.allCases, id: \.rawValue) { scope in
                    scopeChip(scope: scope, label: scope.label, count: searchResults.facetCounts[scope] ?? 0)
                }
            }
        }
    }

    private func scopeChip(
        scope: DocumentSearchScope?,
        label: String,
        count: Int
    ) -> some View {
        let isSelected = state.selectedDocumentSearchScope == scope

        return Button {
            state.selectedDocumentSearchScope = isSelected ? nil : scope
        } label: {
            HStack(spacing: 6) {
                if let scope {
                    Image(systemName: scope.systemImage)
                }
                Text(label)
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
        .disabled(scope != nil && count == 0 && !state.documentSearchText.isEmpty)
    }

    private func resultRow(_ item: DocumentSearchNavigatorItem) -> some View {
        let isFocused = state.isFocusedDocumentSearchResult(item)

        return Button {
            state.focusDocumentSearchResult(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if let pageNumber = item.pageNumber {
                            DocumentPageBadge(pageNumber: pageNumber)
                        }
                    }

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let snippet = item.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    HStack(spacing: 6) {
                        DocumentMetadataBadge(text: item.statusLabel)
                        if let score = item.score {
                            DocumentMetadataBadge(
                                text: "Score \(score.formatted(.number.precision(.fractionLength(1))))"
                            )
                        }
                    }
                }

                if isFocused {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emptyTitle)
                .font(.subheadline.weight(.medium))
            Text(emptyMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 12)
    }

    private func refreshResults() async {
        isSearching = true
        let results = await state.documentSearchResults(
            matching: state.documentSearchText,
            scope: state.selectedDocumentSearchScope
        )
        searchResults = results
        isSearching = false
    }

    private var refreshToken: Int {
        var hasher = Hasher()
        hasher.combine(state.documentSearchText)
        hasher.combine(state.selectedDocumentSearchScope?.rawValue)

        for entry in state.documentSearchEntries {
            hasher.combine(entry.id)
            hasher.combine(entry.title)
            hasher.combine(entry.subtitle)
            hasher.combine(entry.body.prefix(128))
            hasher.combine(entry.pageNumber)
            hasher.combine(entry.offset)
        }

        return hasher.finalize()
    }

    private var summaryText: String {
        if state.documentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Browsing \(searchResults.totalCount) indexed items"
        }

        return "\(searchResults.items.count) of \(searchResults.totalCount) matches"
    }

    private var totalFacetCount: Int {
        searchResults.facetCounts.values.reduce(0, +)
    }

    private var emptyTitle: String {
        state.documentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No indexed document items"
            : "No matches found"
    }

    private var emptyMessage: String {
        state.documentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Headings, comments, bookmarks, and tracked changes will appear here."
            : "Try a different term or widen the selected scope."
    }
}
