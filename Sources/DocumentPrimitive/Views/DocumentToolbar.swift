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
            Picker(DocumentPrimitiveStrings.viewPickerTitle, selection: $state.viewMode) {
                Text(DocumentPrimitiveStrings.pageViewModeTitle).tag(DocumentViewMode.page)
                Text(DocumentPrimitiveStrings.continuousViewModeTitle).tag(DocumentViewMode.continuous)
                Text(DocumentPrimitiveStrings.canvasViewModeTitle).tag(DocumentViewMode.canvas)
            }
            .pickerStyle(.segmented)

            Toggle(DocumentPrimitiveStrings.rulerToggleTitle, isOn: $state.showRuler)
            Toggle(DocumentPrimitiveStrings.formattingToggleTitle, isOn: $state.showFormatting)
            Toggle(
                DocumentPrimitiveStrings.trackToggleTitle,
                isOn: Binding(
                    get: { state.changeTracker.isTracking },
                    set: { state.changeTracker.isTracking = $0 }
                )
            )

            Menu {
                visibilityButton(DocumentPrimitiveStrings.allChangesTitle, visibility: .showAll)
                visibilityButton(DocumentPrimitiveStrings.myChangesTitle, visibility: .showOnlyMine)
                visibilityButton(DocumentPrimitiveStrings.finalViewTitle, visibility: .final)
                visibilityButton(DocumentPrimitiveStrings.originalViewTitle, visibility: .original)
            } label: {
                Label(changeVisibilityLabel, systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)

            Menu {
                headerFooterOptionButton(
                    DocumentPrimitiveStrings.differentFirstPageTitle,
                    enabled: state.currentSectionUsesDifferentFirstPage
                ) {
                    state.setCurrentSectionDifferentFirstPage(!state.currentSectionUsesDifferentFirstPage)
                }

                headerFooterOptionButton(
                    DocumentPrimitiveStrings.differentOddEvenTitle,
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
                Label(DocumentPrimitiveStrings.searchTitle, systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingSearchNavigator, arrowEdge: .bottom) {
                DocumentSearchPopover(state: state)
            }

            Button {
                showingReviewNavigator.toggle()
            } label: {
                Label(DocumentPrimitiveStrings.reviewTitle, systemImage: "list.bullet.rectangle")
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
                .accessibilityLabel(DocumentPrimitiveStrings.previousChangeAccessibilityLabel)

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
                .accessibilityLabel(DocumentPrimitiveStrings.nextChangeAccessibilityLabel)

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
                .accessibilityLabel(DocumentPrimitiveStrings.acceptCurrentChangeTitle)

                Button(role: .destructive) {
                    state.rejectCurrentChange()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(state.currentTrackedChange == nil)
                .accessibilityLabel(DocumentPrimitiveStrings.rejectCurrentChangeTitle)

                Menu {
                    Button(DocumentPrimitiveStrings.acceptCurrentChangeTitle) {
                        state.acceptCurrentChange()
                    }
                    .disabled(state.currentTrackedChange == nil)

                    Button(DocumentPrimitiveStrings.rejectCurrentChangeTitle, role: .destructive) {
                        state.rejectCurrentChange()
                    }
                    .disabled(state.currentTrackedChange == nil)

                    Divider()

                    Button(DocumentPrimitiveStrings.acceptAllChangesTitle) {
                        state.acceptAllChanges()
                    }
                    .disabled(changeCount == 0)

                    Button(DocumentPrimitiveStrings.rejectAllChangesTitle, role: .destructive) {
                        state.rejectAllChanges()
                    }
                    .disabled(changeCount == 0)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .disabled(changeCount == 0)
                .accessibilityLabel(DocumentPrimitiveStrings.reviewActionsAccessibilityLabel)
            }

            HStack(spacing: theme.spacing.toolbarGroupSpacing) {
                Button {
                    state.goToPreviousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToPreviousPage)
                .accessibilityLabel(DocumentPrimitiveStrings.previousPageAccessibilityLabel)

                Text(DocumentPrimitiveStrings.pageLabel(state.currentPage))
                    .font(theme.typography.toolbarLabel)
                    .foregroundStyle(theme.colors.secondary)

                Button {
                    state.goToNextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!state.canGoToNextPage)
                .accessibilityLabel(DocumentPrimitiveStrings.nextPageAccessibilityLabel)
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
            DocumentPrimitiveStrings.headersTitle
        case (true, false):
            DocumentPrimitiveStrings.headersFirstTitle
        case (false, true):
            DocumentPrimitiveStrings.headersOddEvenTitle
        case (true, true):
            DocumentPrimitiveStrings.headersFirstOddEvenTitle
        }
    }

    private var changeVisibilityLabel: String {
        switch state.changeTracker.showChanges {
        case .showAll:
            DocumentPrimitiveStrings.allChangesTitle
        case .showOnlyMine:
            DocumentPrimitiveStrings.myChangesTitle
        case .final_:
            DocumentPrimitiveStrings.finalViewTitle
        case .original:
            DocumentPrimitiveStrings.originalViewTitle
        }
    }

    private var changeCountLabel: String {
        if changeCount == 0 {
            return DocumentPrimitiveStrings.noChangesTitle
        }
        if let currentTrackedChangeID = state.currentTrackedChangeID,
           let index = state.reviewableTrackedChanges.firstIndex(where: { $0.id == currentTrackedChangeID }) {
            return DocumentPrimitiveStrings.changeCountPosition(current: index + 1, total: changeCount)
        }
        return DocumentPrimitiveStrings.changeCount(changeCount)
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
