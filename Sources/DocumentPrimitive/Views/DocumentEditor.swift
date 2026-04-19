import DragAndDropPrimitive
import RichTextPrimitive
import RulerPrimitive
import SwiftUI

public struct DocumentEditor: View {
    @Bindable private var state: DocumentEditorState
    @Environment(\.documentTheme) private var theme

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
            state.syncCurrentLocation(using: state.richTextState)
        }
        .onChange(of: state.richTextState.selection) { _, _ in
            state.syncCurrentLocation(using: state.richTextState)
        }
        .onChange(of: state.richTextState.focusedBlockID) { _, _ in
            state.syncCurrentLocation(using: state.richTextState)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        let projection = state.reviewDisplayProjection
        let styleSheet = state.document.styles.textStyleSheet()

        if projection.isReadOnly {
            PrintPreview(state: state)
        } else {
            switch state.viewMode {
            case .page:
                PrintPreview(state: state)
            case .continuous, .canvas:
                ScrollView {
                    VStack(spacing: theme.spacing.sectionGap) {
                        ForEach(state.document.sections) { section in
                            let sectionEditorState = state.richTextState(forSection: section.id)
                            HStack(alignment: .top, spacing: theme.spacing.reorderHandleGap) {
                                SectionReorderHandle(section: section)

                                RichTextEditor(
                                    state: sectionEditorState,
                                    dataSource: state.dataSource(for: section.id),
                                    styleSheet: styleSheet,
                                    showsBlockNavigator: true
                                )
                                .frame(minHeight: theme.metrics.sectionMinHeight)
                                .padding()
                                .background(theme.colors.background)
                                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.sectionCardCornerRadius, style: .continuous))
                                .shadow(color: .black.opacity(theme.opacity.sectionShadowOpacity), radius: theme.shadow.sectionRadius, y: theme.shadow.sectionY)
                                .onChange(of: sectionEditorState.selection) { _, _ in
                                    state.syncCurrentLocation(using: sectionEditorState)
                                }
                                .onChange(of: sectionEditorState.focusedBlockID) { _, _ in
                                    state.syncCurrentLocation(using: sectionEditorState)
                                }
                            }
                        }
                    }
                    .reorderable(items: sectionBinding) { _ in }
                    .padding(theme.spacing.containerPadding)
                }
                .background(Color.secondary.opacity(theme.opacity.canvasFill))
            }
        }
    }

    private var rulerView: some View {
        DocumentRulerView(snapshot: state.rulerSnapshot()) { marker, position in
            state.moveRulerMarker(marker.markerType, to: position)
        }
    }

    private var sectionBinding: Binding<[DocumentSection]> {
        Binding(
            get: { state.document.sections },
            set: { state.replaceSections($0) }
        )
    }
}

private struct SectionReorderHandle: View {
    let section: DocumentSection
    @Environment(\.documentTheme) private var theme

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.colors.secondary)
            .padding(.horizontal, theme.spacing.reorderHandleHorizontalPadding)
            .padding(.vertical, theme.spacing.reorderHandleVerticalPadding)
            .background(theme.mutedFill, in: RoundedRectangle(cornerRadius: theme.metrics.reorderHandleCornerRadius, style: .continuous))
            .vantageDraggable(
                DragItem(
                    content: section.id.rawValue,
                    previewLabel: "Section",
                    sourceID: DragDropID(section.id.rawValue)
                )
            )
            .accessibilityLabel("Reorder section")
            .accessibilityHint("Drag to move this section within the document")
    }
}

private struct DocumentRulerView: View {
    let snapshot: DocumentRulerSnapshot
    let onMoveMarker: (RulerMarkerItem, CGFloat) -> Void
    @Environment(\.documentTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / max(snapshot.configuration.length, 1)

            ZStack(alignment: .topLeading) {
                ForEach(ticks(width: proxy.size.width, scale: scale)) { tick in
                    tickView(tick)
                }

                ForEach(snapshot.markers) { marker in
                    markerView(marker, scale: scale, width: proxy.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: theme.metrics.rulerHeight)
        .background(theme.mutedFill)
    }

    private func tickView(_ tick: RulerTick) -> some View {
        VStack(spacing: 1) {
            Rectangle()
                .fill(tick.isMajor ? theme.colors.secondary : theme.colors.secondary.opacity(theme.opacity.rulerTickMinor))
                .frame(width: 1, height: tick.isMajor ? 14 : 8)

            if let label = tick.label {
                Text(label)
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colors.secondary)
                    .fixedSize()
            }
        }
        .position(x: tick.x, y: tick.isMajor ? 14 : 7)
    }

    private func markerView(
        _ marker: RulerMarkerItem,
        scale: CGFloat,
        width: CGFloat
    ) -> some View {
        let x = min(max(marker.position * scale, 0), width)

        return Image(systemName: icon(for: marker.markerType))
            .font(theme.typography.caption2.weight(.semibold))
            .foregroundStyle(marker.isDraggable ? theme.colors.accent : theme.colors.secondary)
            .padding(3)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(theme.colors.secondary.opacity(theme.opacity.rulerMarkerBorder), lineWidth: 0.5)
            )
            .position(x: x, y: 24)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard marker.isDraggable, scale > 0 else { return }
                        onMoveMarker(marker, (x + value.translation.width) / scale)
                    }
            )
            .accessibilityLabel(label(for: marker.markerType))
    }

    private func ticks(width: CGFloat, scale: CGFloat) -> [RulerTick] {
        let configuration = snapshot.configuration
        let totalUnits = max(Int(ceil(configuration.pointsToUnit(configuration.length))), 1)
        let tickCount = totalUnits * configuration.subdivisions

        return (0...tickCount).compactMap { index in
            let unitValue = CGFloat(index) / CGFloat(configuration.subdivisions)
            let position = configuration.unitToPoints(unitValue)
            let x = position * scale
            guard x >= 0, x <= width else { return nil }

            let isMajor = index.isMultiple(of: configuration.subdivisions)
            return RulerTick(
                id: index,
                x: x,
                isMajor: isMajor,
                label: isMajor ? "\(Int(unitValue))\(configuration.unit.abbreviation)" : nil
            )
        }
    }

    private func icon(for markerType: RulerMarkerType) -> String {
        switch markerType {
        case .leftMargin:
            "arrowtriangle.right.fill"
        case .rightMargin:
            "arrowtriangle.left.fill"
        case .firstLineIndent:
            "arrowtriangle.down.fill"
        case .hangingIndent:
            "arrowtriangle.up.fill"
        case .tabStop:
            "t.square"
        case .columnGuide:
            "rectangle.split.3x1"
        case .custom:
            "diamond.fill"
        }
    }

    private func label(for markerType: RulerMarkerType) -> String {
        switch markerType {
        case .leftMargin:
            "Left margin"
        case .rightMargin:
            "Right margin"
        case .firstLineIndent:
            "First line indent"
        case .hangingIndent:
            "Hanging indent"
        case let .tabStop(alignment):
            "\(alignment.rawValue.capitalized) tab stop"
        case .columnGuide:
            "Column guide"
        case let .custom(label):
            label
        }
    }
}

private struct RulerTick: Identifiable {
    let id: Int
    let x: CGFloat
    let isMajor: Bool
    let label: String?
}
