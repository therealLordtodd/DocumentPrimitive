import SwiftUI

@MainActor
struct DocumentSearchPopover: View {
    @Bindable private var state: DocumentEditorState
    @State private var searchResults = DocumentSearchNavigatorResults(items: [], totalCount: 0, facetCounts: [:])
    @State private var isSearching = false
    @Environment(\.documentTheme) private var theme

    init(state: DocumentEditorState) {
        self._state = Bindable(wrappedValue: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.popoverContentSpacing) {
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
                    LazyVStack(alignment: .leading, spacing: theme.spacing.navigatorRowSpacing) {
                        ForEach(searchResults.items) { item in
                            resultRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(theme.spacing.popoverPadding)
        .frame(width: theme.metrics.popoverWidth, height: theme.metrics.popoverHeight)
        .task(id: refreshToken) {
            await refreshResults()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Search Document")
                    .font(theme.typography.headline)
                Text(summaryText)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
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
            HStack(spacing: theme.spacing.scopeChipGap) {
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
            HStack(spacing: theme.spacing.annotationBadgeGap) {
                if let scope {
                    Image(systemName: scope.systemImage)
                }
                Text(label)
                Text("\(count)")
                    .font(theme.typography.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.secondary)
            }
            .padding(.horizontal, theme.spacing.scopeChipHorizontalPadding)
            .padding(.vertical, theme.spacing.scopeChipVerticalPadding)
            .background(
                Capsule()
                    .fill(isSelected ? theme.colors.accent.opacity(theme.opacity.selectedFill + 0.02) : theme.mutedFill)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? theme.colors.accent.opacity(theme.opacity.scopeChipSelectedBorder) : theme.colors.secondary.opacity(theme.opacity.scopeChipBorder))
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
            HStack(alignment: .top, spacing: theme.spacing.navigatorRowIconGap) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(isFocused ? theme.colors.accent : theme.colors.secondary)
                    .frame(width: theme.metrics.navigatorIconWidth)

                VStack(alignment: .leading, spacing: theme.spacing.annotationBadgeGap) {
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.navigatorRowSpacing) {
                        Text(item.title)
                            .font(theme.typography.rowTitle)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if let pageNumber = item.pageNumber {
                            DocumentPageBadge(pageNumber: pageNumber)
                        }
                    }

                    Text(item.subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.secondary)
                        .lineLimit(2)

                    if let snippet = item.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.secondary)
                            .lineLimit(3)
                    }

                    HStack(spacing: theme.spacing.annotationBadgeGap) {
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
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .padding(theme.spacing.navigatorRowPadding)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cardCornerRadius)
                    .fill(isFocused ? theme.selectedFill : theme.subtleFill)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: theme.spacing.annotationBadgeGap) {
            Text(emptyTitle)
                .font(theme.typography.rowTitle)
            Text(emptyMessage)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, theme.spacing.navigatorRowPadding)
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
