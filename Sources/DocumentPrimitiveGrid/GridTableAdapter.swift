#if canImport(GridPrimitive)
import DocumentPrimitive
import Foundation
import GridPrimitive

public struct GridTableAdapter: Sendable {
    public init() {}

    public func topLeftCellAddress() -> CellAddress {
        CellAddress(column: ColumnID("A"), row: RowID("1"))
    }

    public func suggestedGridIdentifier(for section: DocumentSection) -> String {
        "grid-\(section.id.rawValue)"
    }
}
#endif
