#if canImport(GridPrimitive) && canImport(GridPrimitiveTable)
import DocumentPrimitive
import Foundation
import GridPrimitive
import GridPrimitiveTable
import Observation
import RichTextPrimitive
import SwiftUI

@MainActor
@Observable
final class GridTableEditorModel {
    private let adapter = GridTableAdapter()
    private let editable: Bool

    private var observerID: UUID?

    var table: TableContent
    var dataSource: ArrayGridDataSource
    var dataProvider: GridDataSourceAdapter
    var state: GridState
    var onTableChange: ((TableContent) -> Void)?

    init(
        table: TableContent,
        editable: Bool,
        onTableChange: ((TableContent) -> Void)? = nil
    ) {
        self.table = table
        self.editable = editable
        self.onTableChange = onTableChange

        let adapter = GridTableAdapter()
        let dataSource = adapter.dataSource(for: table, editable: editable)
        self.dataSource = dataSource
        self.dataProvider = GridDataSourceAdapter(source: dataSource)
        self.state = GridState(columns: dataSource.columns)
        observeDataSource()
    }

    func updateTable(_ table: TableContent) {
        guard table != self.table else { return }

        self.table = table
        if let observerID {
            dataSource.removeMutationObserver(observerID)
            self.observerID = nil
        }

        let newDataSource = adapter.dataSource(for: table, editable: editable)
        dataSource = newDataSource
        dataProvider = GridDataSourceAdapter(source: newDataSource)
        state = GridState(columns: newDataSource.columns)
        observeDataSource()
    }

    private func observeDataSource() {
        observerID = dataSource.addMutationObserver { [weak self] _ in
            guard let self else { return }
            onTableChange?(
                adapter.tableContent(
                    from: dataSource,
                    caption: table.caption,
                    columnWidths: table.columnWidths
                )
            )
        }
    }
}

@MainActor
public struct GridTableEditor: View {
    @State private var model: GridTableEditorModel

    private let table: TableContent
    private let configuration: TableConfiguration

    public init(
        table: TableContent,
        editable: Bool = false,
        configuration: TableConfiguration? = nil,
        onTableChange: ((TableContent) -> Void)? = nil
    ) {
        self.table = table
        self.configuration = Self.resolvedConfiguration(
            requested: configuration,
            editable: editable
        )
        _model = State(
            initialValue: GridTableEditorModel(
                table: table,
                editable: editable,
                onTableChange: onTableChange
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let caption = model.table.caption?.plainText, !caption.isEmpty {
                Text(caption)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            TableView(
                dataProvider: model.dataProvider,
                state: model.state,
                configuration: configuration
            )
        }
        .onChange(of: table) { _, newValue in
            model.updateTable(newValue)
        }
    }

    private static func resolvedConfiguration(
        requested: TableConfiguration?,
        editable: Bool
    ) -> TableConfiguration {
        var configuration = requested ?? (editable ? .compact : .readOnly)
        configuration.allowsEditing = editable
        return configuration
    }
}

@MainActor
public struct GridTableBlockEditor: View {
    private let block: Block
    private let editable: Bool
    private let configuration: TableConfiguration?
    private let onBlockChange: ((Block) -> Void)?

    private let adapter = GridTableAdapter()

    public init(
        block: Block,
        editable: Bool = false,
        configuration: TableConfiguration? = nil,
        onBlockChange: ((Block) -> Void)? = nil
    ) {
        self.block = block
        self.editable = editable
        self.configuration = configuration
        self.onBlockChange = onBlockChange
    }

    public var body: some View {
        if case let .table(table) = block.content {
            GridTableEditor(
                table: table,
                editable: editable,
                configuration: configuration
            ) { updatedTable in
                onBlockChange?(
                    Block(
                        id: block.id,
                        type: .table,
                        content: .table(updatedTable),
                        metadata: block.metadata
                    )
                )
            }
        } else {
            Text("Grid table editor requires a table block.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
public struct DocumentTableBlockEditor: View {
    @Bindable private var editorState: DocumentEditorState

    private let sectionID: SectionID
    private let blockID: BlockID
    private let editable: Bool
    private let configuration: TableConfiguration?

    public init(
        editorState: DocumentEditorState,
        sectionID: SectionID,
        blockID: BlockID,
        editable: Bool = false,
        configuration: TableConfiguration? = nil
    ) {
        self.editorState = editorState
        self.sectionID = sectionID
        self.blockID = blockID
        self.editable = editable
        self.configuration = configuration
    }

    public var body: some View {
        if let block = editorState.block(in: sectionID, id: blockID) {
            GridTableBlockEditor(
                block: block,
                editable: editable,
                configuration: configuration
            ) { updatedBlock in
                editorState.replaceBlock(updatedBlock, in: sectionID)
            }
        } else {
            Text("Table block not found.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
