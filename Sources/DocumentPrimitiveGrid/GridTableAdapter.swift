#if canImport(GridPrimitive)
import DocumentPrimitive
import Foundation
import GridPrimitive
import RichTextPrimitive

public struct GridTableAdapter: Sendable {
    public init() {}

    public func topLeftCellAddress() -> CellAddress {
        CellAddress(column: ColumnID("A"), row: RowID("1"))
    }

    public func suggestedGridIdentifier(for section: DocumentSection) -> String {
        "grid-\(section.id.rawValue)"
    }

    @MainActor
    public func dataSource(
        for table: TableContent,
        editable: Bool = false
    ) -> ArrayGridDataSource {
        let columnCount = max(table.columnWidths?.count ?? 0, table.rows.map(\.count).max() ?? 0)
        let columns = (0..<columnCount).map { index in
            GridColumn(
                id: columnID(for: index),
                title: columnTitle(for: index),
                valueType: .text,
                width: resolvedWidth(for: index, explicitWidths: table.columnWidths),
                sortable: false,
                editable: editable,
                visible: true
            )
        }
        let rows = table.rows.enumerated().map { rowIndex, row in
            let cells = Dictionary(uniqueKeysWithValues: (0..<columnCount).map { columnIndex in
                let value = row[safe: columnIndex]?.plainText ?? ""
                return (columnID(for: columnIndex), CellValue.text(value))
            })
            return GridRow(id: rowID(for: rowIndex), cells: cells)
        }

        let dataSource = ArrayGridDataSource(columns: columns, rows: rows)
        dataSource.setEditabilityResolver { _ in editable }
        return dataSource
    }

    @MainActor
    public func tableContent(
        from dataSource: any GridDataSource,
        caption: TextContent? = nil,
        columnWidths: [CGFloat]? = nil
    ) -> TableContent {
        let rows = (0..<dataSource.rowCount).map { rowIndex in
            let row = dataSource.row(at: rowIndex)
            return dataSource.columns.map { column in
                textContent(from: row.cells[column.id] ?? .empty)
            }
        }

        return TableContent(
            rows: rows,
            columnWidths: columnWidths ?? inferredColumnWidths(from: dataSource.columns),
            caption: caption
        )
    }

    @MainActor
    public func tableBlock(
        from dataSource: any GridDataSource,
        caption: TextContent? = nil,
        columnWidths: [CGFloat]? = nil,
        blockID: BlockID = BlockID(UUID().uuidString)
    ) -> Block {
        Block(
            id: blockID,
            type: .table,
            content: .table(
                tableContent(
                    from: dataSource,
                    caption: caption,
                    columnWidths: columnWidths
                )
            )
        )
    }

    private func textContent(from value: CellValue) -> TextContent {
        .plain(plainText(from: value))
    }

    private func plainText(from value: CellValue) -> String {
        switch value {
        case let .text(text):
            text
        case let .number(number):
            number.formatted()
        case let .bool(boolean):
            boolean ? "TRUE" : "FALSE"
        case let .date(date):
            date.formatted(date: .numeric, time: .omitted)
        case let .data(data):
            switch data.kind {
            case .image:
                "[Image]"
            case .attachment:
                "[Attachment]"
            }
        case let .error(error):
            error.description
        case .empty:
            ""
        }
    }

    private func resolvedWidth(for index: Int, explicitWidths: [CGFloat]?) -> GridColumnWidth {
        if let width = explicitWidths?[safe: index] {
            return .fixed(width)
        }
        return .flexible(min: 80, max: 420)
    }

    private func inferredColumnWidths(from columns: [GridColumn]) -> [CGFloat]? {
        guard !columns.isEmpty else { return nil }
        return columns.map { column in
            switch column.width {
            case let .fixed(width):
                width
            case let .flexible(minimum, _):
                minimum
            case let .fraction(fraction):
                max(80, 240 * fraction)
            }
        }
    }

    private func columnID(for index: Int) -> ColumnID {
        ColumnID(columnTitle(for: index))
    }

    private func columnTitle(for index: Int) -> String {
        var remainder = index
        var title = ""

        repeat {
            let scalar = UnicodeScalar(65 + (remainder % 26))!
            title = String(Character(scalar)) + title
            remainder = remainder / 26 - 1
        } while remainder >= 0

        return title
    }

    private func rowID(for index: Int) -> RowID {
        RowID(String(index + 1))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
