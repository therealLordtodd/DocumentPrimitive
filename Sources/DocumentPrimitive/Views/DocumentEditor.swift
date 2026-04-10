import RichTextPrimitive
import RulerPrimitive
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
                    VStack(spacing: 20) {
                        ForEach(state.document.sections) { section in
                            let sectionEditorState = state.richTextState(forSection: section.id)
                            RichTextEditor(
                                state: sectionEditorState,
                                dataSource: state.dataSource(for: section.id),
                                styleSheet: styleSheet
                            )
                            .frame(minHeight: 220)
                            .padding()
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
                            .onChange(of: sectionEditorState.selection) { _, _ in
                                state.syncCurrentLocation(using: sectionEditorState)
                            }
                            .onChange(of: sectionEditorState.focusedBlockID) { _, _ in
                                state.syncCurrentLocation(using: sectionEditorState)
                            }
                        }
                    }
                    .padding(24)
                }
                .background(Color.secondary.opacity(0.05))
            }
        }
    }

    private var rulerView: some View {
        DocumentRulerView(snapshot: state.rulerSnapshot()) { marker, position in
            state.moveRulerMarker(marker.markerType, to: position)
        }
    }
}

private struct DocumentRulerView: View {
    let snapshot: DocumentRulerSnapshot
    let onMoveMarker: (RulerMarkerItem, CGFloat) -> Void

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
        .frame(height: 34)
        .background(Color.secondary.opacity(0.08))
    }

    private func tickView(_ tick: RulerTick) -> some View {
        VStack(spacing: 1) {
            Rectangle()
                .fill(tick.isMajor ? Color.secondary : Color.secondary.opacity(0.45))
                .frame(width: 1, height: tick.isMajor ? 14 : 8)

            if let label = tick.label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
            .font(.caption2.weight(.semibold))
            .foregroundStyle(marker.isDraggable ? Color.accentColor : Color.secondary)
            .padding(3)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
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
