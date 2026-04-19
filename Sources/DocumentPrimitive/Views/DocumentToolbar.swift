import SwiftUI
import TrackChangesPrimitive

public struct DocumentToolbar: View {
    @Bindable private var state: DocumentEditorState
    @State private var showingSearchNavigator = false
    @State private var showingReviewNavigator = false
    @Environment(\.documentTheme) private var theme

    public init(state: DocumentEditorState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: theme.spacing.toolbarItemSpacing) {
            Picker("View", selection: $state.viewMode) {
                Text("Page").tag(DocumentViewMode.page)
                Text("Continuous").tag(DocumentViewMode.continuous)
                Text("Canvas").tag(DocumentViewMode.canvas)
            }
            .pickerStyle(.segmented)

            Toggle("Ruler", isOn: $state.showRuler)
            Toggle("Formatting", isOn: $state.showFormatting)
            Toggle(
                "Track",
                isOn: Binding(
                    get: { state.changeTracker.isTracking },
                    set: { state.changeTracker.isTracking = $0 }
                )
            )

            Menu {
                visibilityButton("All Changes", visibility: .showAll)
                visibilityButton("My Changes", visibility: .showOnlyMine)
                visibilityButton("Final View", visibility: .final)
                visibilityButton("Original View", visibility: .original)
            } label: {
                Label(changeVisibilityLabel, systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)

            Menu {
                headerFooterOptionButton(
                    "Different First Page",
                    enabled: state.currentSectionUsesDifferentFirstPage
                ) {
                    state.setCurrentSectionDifferentFirstPage(!state.currentSectionUsesDifferentFirstPage)
                }

                headerFooterOptionButton(
                    "Different Odd & Even",
                    enabled: state.currentSectionUsesDifferentOddEven
                ) {
                    state.setCurrentSectionDifferentOddEven(!state.currentSectionUsesDifferentOddEven)
                }
            } label: {
                Label(headerFooterLabel, systemImage: "doc.text")
            }
            .menuStyle(.borderlessButton)
            .disabled(!state.canEditCurrentSectionHeaderFooterOptions)

            Button {
                showingSearchNavigator.toggle()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingSearchNavigator, arrowEdge: .bottom) {
                DocumentSearchPopover(state: state)
            }

            Button {
                showingReviewNavigator.toggle()
            } label: {
                Label("Review", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingReviewNavigator, arrowEdge: .bottom) {
                ReviewNavigatorPopover(state: state)
            }

            Spacer()

            HStack(spacing: theme.spacing.toolbarGroupSpacing) {
                Button {
                    state.goToPreviousChange()
                } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .buttonStyle(.borderless)
                .disabled(changeCount == 0)

                Text(changeCountLabel)
                    .font(theme.typography.toolbarLabel)
                    .foregroundStyle(theme.colors.secondary)
                    .frame(minWidth: theme.metrics.changeCountMinWidth, alignment: .center)

                Button {
                    state.goToNextChange()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .disabled(changeCount == 0)

                if let currentChangeSummary = state.currentTrackedChangeSummary {
                    Text(currentChangeSummary)
                        .font(theme.typography.toolbarLabel)
                        .foregroundStyle(theme.colors.secondary)
                        .lineLimit(1)
                        .frame(minWidth: theme.metrics.changeSummaryMinWidth, maxWidth: theme.metrics.changeSummaryMaxWidth, alignment: .leading)
                }

                Button {
                    state.acceptCurrentChange()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(state.currentTrackedChange == nil)

                Button(role: .destructive) {
                    state.rejectCurrentChange()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(state.currentTrackedChange == nil)

                Menu {
                    Button("Accept Current Change") {
                        state.acceptCurrentChange()
                    }
                    .disabled(state.currentTrackedChange == nil)

                    Button("Reject Current Change", role: .destructive) {
                        state.rejectCurrentChange()
                    }
                    .disabled(state.currentTrackedChange == nil)

                    Divider()

                    Button("Accept All Changes") {
                        state.acceptAllChanges()
                    }
                    .disabled(changeCount == 0)

                    Button("Reject All Changes", role: .destructive) {
                        state.rejectAllChanges()
                    }
                    .disabled(changeCount == 0)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .disabled(changeCount == 0)
            }

            HStack(spacing: theme.spacing.toolbarGroupSpacing) {
                Button {
                    state.goToPreviousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToPreviousPage)

                Text("Page \(state.currentPage)")
                    .font(theme.typography.toolbarLabel)
                    .foregroundStyle(theme.colors.secondary)

                Button {
                    state.goToNextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToNextPage)
            }
        }
        .padding(.horizontal, theme.spacing.toolbarHorizontalPadding)
        .padding(.vertical, theme.spacing.toolbarVerticalPadding)
    }

    private var changeCount: Int {
        state.reviewableTrackedChanges.count
    }

    private var headerFooterLabel: String {
        switch (state.currentSectionUsesDifferentFirstPage, state.currentSectionUsesDifferentOddEven) {
        case (false, false):
            "Headers"
        case (true, false):
            "Headers: First"
        case (false, true):
            "Headers: Odd/Even"
        case (true, true):
            "Headers: First + Odd/Even"
        }
    }

    private var changeVisibilityLabel: String {
        switch state.changeTracker.showChanges {
        case .showAll:
            "All Changes"
        case .showOnlyMine:
            "My Changes"
        case .final_:
            "Final View"
        case .original:
            "Original View"
        }
    }

    private var changeCountLabel: String {
        if changeCount == 0 {
            return "No Changes"
        }
        if let currentTrackedChangeID = state.currentTrackedChangeID,
           let index = state.reviewableTrackedChanges.firstIndex(where: { $0.id == currentTrackedChangeID }) {
            return "Change \(index + 1)/\(changeCount)"
        }
        return changeCount == 1 ? "1 Change" : "\(changeCount) Changes"
    }
    @ViewBuilder
    private func visibilityButton(_ title: String, visibility: ChangeVisibility) -> some View {
        Button {
            state.changeTracker.showChanges = visibility
        } label: {
            HStack {
                Text(title)
                if state.changeTracker.showChanges == visibility {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    @ViewBuilder
    private func headerFooterOptionButton(
        _ title: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                if enabled {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
