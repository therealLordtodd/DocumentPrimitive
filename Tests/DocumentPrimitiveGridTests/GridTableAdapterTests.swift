#if canImport(GridPrimitive)
import Foundation
import Testing
@testable import DocumentPrimitiveGrid
@testable import DocumentPrimitive
@testable import GridPrimitive
@testable import RichTextPrimitive

@Suite("DocumentPrimitiveGrid Tests")
struct GridTableAdapterTests {
    @Test func adapterProvidesTopLeftAddress() {
        let adapter = GridTableAdapter()
        #expect(adapter.topLeftCellAddress().description == "A:1")
    }

    @MainActor
    @Test func tableContentBuildsGridDataSource() {
        let adapter = GridTableAdapter()
        let table = TableContent(
            rows: [
                [.plain("Name"), .plain("City")],
                [.plain("Ada"), .plain("London")],
            ],
            columnWidths: [120, 180],
            caption: .plain("Contacts")
        )

        let dataSource = adapter.dataSource(for: table, editable: true)

        #expect(dataSource.columns.map(\.title) == ["A", "B"])
        #expect(dataSource.columns[0].width == .fixed(120))
        #expect(dataSource.rowCount == 2)
        #expect(dataSource.row(at: 1).cells["B"] == .text("London"))
        #expect(dataSource.isCellEditable(CellAddress(column: "A", row: "1")))
    }

    @MainActor
    @Test func gridDataSourceRoundTripsBackToTableContent() {
        let adapter = GridTableAdapter()
        let columns = [
            GridColumn(id: "A", title: "A", valueType: .text, width: .fixed(140), sortable: false),
            GridColumn(id: "B", title: "B", valueType: .text, width: .fixed(160), sortable: false),
            GridColumn(id: "AA", title: "AA", valueType: .text, width: .fixed(200), sortable: false),
        ]
        let rows = [
            GridRow(id: "1", cells: ["A": .text("One"), "B": .number(2), "AA": .bool(true)]),
            GridRow(id: "2", cells: ["A": .empty, "B": .text("Tail"), "AA": .data(.init(kind: .image, storage: .reference("https://example.com/image.png")))]),
        ]
        let dataSource = ArrayGridDataSource(columns: columns, rows: rows)

        let table = adapter.tableContent(from: dataSource, caption: .plain("Round Trip"))

        #expect(table.caption?.plainText == "Round Trip")
        #expect(table.columnWidths == [140, 160, 200])
        #expect(table.rows.count == 2)
        #expect(table.rows[0][0].plainText == "One")
        #expect(table.rows[0][1].plainText == "2")
        #expect(table.rows[0][2].plainText == "TRUE")
        #expect(table.rows[1][2].plainText == "[Image]")
    }

    @MainActor
    @Test func tableBlockUsesTableContentRoundTrip() {
        let adapter = GridTableAdapter()
        let dataSource = ArrayGridDataSource(
            columns: [
                GridColumn(id: "A", title: "A", valueType: .text),
                GridColumn(id: "B", title: "B", valueType: .text),
                GridColumn(id: "Z", title: "Z", valueType: .text),
                GridColumn(id: "AA", title: "AA", valueType: .text),
            ],
            rows: [
                GridRow(id: "1", cells: ["A": .text("v1"), "B": .text("v2"), "Z": .text("v26"), "AA": .text("v27")]),
            ]
        )

        let block = adapter.tableBlock(from: dataSource, caption: .plain("Sheet"), blockID: "table")

        guard case let .table(content) = block.content else {
            Issue.record("Expected table block content")
            return
        }

        #expect(block.id == "table")
        #expect(content.caption?.plainText == "Sheet")
        #expect(content.rows.first?.last?.plainText == "v27")
    }

    @MainActor
    @Test func gridTableEditorModelPublishesMutationsBackToTableContent() {
        var emittedTables: [TableContent] = []
        let model = GridTableEditorModel(
            table: TableContent(
                rows: [[.plain("Original")]],
                caption: .plain("Inventory")
            ),
            editable: true
        ) { emittedTables.append($0) }

        model.dataSource.updateCell(CellAddress(column: "A", row: "1"), value: .text("Updated"))

        #expect(emittedTables.last?.caption?.plainText == "Inventory")
        #expect(emittedTables.last?.rows.first?.first?.plainText == "Updated")
    }

    @MainActor
    @Test func gridTableEditorModelRebuildsForExternalTableChanges() {
        let model = GridTableEditorModel(
            table: TableContent(rows: [[.plain("One")]]),
            editable: false
        )

        model.updateTable(
            TableContent(
                rows: [[.plain("A"), .plain("B"), .plain("C")]],
                columnWidths: [100, 120, 140],
                caption: .plain("Rebuilt")
            )
        )

        #expect(model.dataSource.columns.map(\.id.rawValue) == ["A", "B", "C"])
        #expect(model.table.caption?.plainText == "Rebuilt")
        #expect(model.dataSource.row(at: 0).cells["C"] == .text("C"))
    }
}
#endif
