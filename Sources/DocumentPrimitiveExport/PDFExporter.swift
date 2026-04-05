import CoreGraphics
import DocumentPrimitive
import ExportKit
import Foundation
import UniformTypeIdentifiers

public struct PDFExporter: DocumentExporter {
    public let formatID = "pdf"
    public let fileExtension = "pdf"
    public let utType = UTType.pdf

    public init() {}

    public func export(_ document: ExportableDocument, options: ExportOptions) async throws -> Data {
        _ = options
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        guard
            let consumer = CGDataConsumer(data: data),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, [
                kCGPDFContextTitle as String: document.metadata.title,
            ] as CFDictionary)
        else {
            return Data()
        }

        let pages = max(1, Int(ceil(Double(max(document.blocks.count, 1)) / 24.0)))
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()

        return data as Data
    }
}
