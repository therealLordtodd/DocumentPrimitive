#if canImport(GridPrimitive)
import Foundation
import Testing
@testable import DocumentPrimitiveGrid
@testable import DocumentPrimitive

@Suite("DocumentPrimitiveGrid Tests")
struct GridTableAdapterTests {
    @Test func adapterProvidesTopLeftAddress() {
        let adapter = GridTableAdapter()
        #expect(adapter.topLeftCellAddress().description == "A:1")
    }
}
#endif
