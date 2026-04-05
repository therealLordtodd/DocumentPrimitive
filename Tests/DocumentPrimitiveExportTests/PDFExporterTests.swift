import CoreGraphics
import ExportKit
import Foundation
import ImageIO
import Testing
#if canImport(PDFKit)
import PDFKit
#endif
import UniformTypeIdentifiers
@testable import DocumentPrimitive
@testable import DocumentPrimitiveExport
@testable import RichTextPrimitive

@Suite("PDFExporter Tests")
struct PDFExporterTests {
    @Test func exportsRenderablePDFData() async throws {
        let longText = String(repeating: "Exportable paragraph ", count: 600)
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .heading, content: .heading(.plain("Intro"), level: 1)),
                        Block(type: .paragraph, content: .text(.plain(longText))),
                        Block(type: .divider, content: .divider),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())

        #expect(data.starts(with: Data("%PDF".utf8)))
        #expect(data.count > 512)

        let provider = try #require(CGDataProvider(data: data as CFData))
        let pdf = try #require(CGPDFDocument(provider))
        #expect(pdf.numberOfPages >= 1)
    }

    #if canImport(PDFKit)
    @Test func exportsSectionHeadersAndResolvedFieldTokens() async throws {
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(type: .paragraph, content: .text(.plain(String(repeating: "Body ", count: 400)))),
                    ],
                    headerFooter: HeaderFooterConfig(
                        header: HeaderFooter(center: [TextRun(text: "Hdr {PAGE}")]),
                        footer: HeaderFooter(right: [TextRun(text: "{TITLE}")])
                    ),
                    startPageNumber: 3
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())
        let pdf = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdf.page(at: 0)?.string)

        #expect(firstPage.contains("Hdr 3"))
        #expect(firstPage.contains("PDF Draft"))
    }

    @Test func exportsPageBottomFootnotes() async throws {
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(id: "anchor", type: .paragraph, content: .text(.plain(String(repeating: "Body ", count: 200)))),
                    ],
                    footnotes: [
                        Footnote(anchorBlockID: "anchor", content: .plain("Footnote body")),
                    ]
                ),
            ],
            settings: DocumentSettings(
                footnoteConfig: FootnoteConfig(placement: .pageBottom)
            )
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())
        let pdf = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdf.page(at: 0)?.string)

        #expect(firstPage.contains("Footnote body"))
    }

    @Test func exportsTableCaptionsIntoPDFText() async throws {
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(
                            type: .table,
                            content: .table(
                                TableContent(
                                    rows: [
                                        [.plain("Quarter"), .plain("Revenue")],
                                        [.plain("Q1"), .plain("$120k")],
                                    ],
                                    caption: .plain("Quarterly Results")
                                )
                            )
                        ),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())
        let pdf = try #require(PDFDocument(data: data))
        let firstPage = try #require(pdf.page(at: 0)?.string)

        #expect(firstPage.contains("Quarterly Results"))
        #expect(firstPage.contains("Quarter"))
        #expect(firstPage.contains("$120k"))
    }
    #endif

    @Test func embedsRealImagesIntoPDF() async throws {
        let imageData = try makePNGData()
        let document = Document(
            title: "PDF Draft",
            sections: [
                DocumentSection(
                    blocks: [
                        Block(
                            type: .image,
                            content: .image(
                                ImageContent(
                                    data: imageData,
                                    altText: "Revenue chart",
                                    size: CGSize(width: 120, height: 80)
                                )
                            )
                        ),
                    ]
                ),
            ]
        )

        let exportable = BlockToExportMapper().map(document: document)
        let data = try await PDFExporter().export(exportable, options: ExportOptions())
        let rawPDF = String(data: data, encoding: .isoLatin1) ?? ""

        #expect(rawPDF.contains("/Subtype /Image"))

        #if canImport(PDFKit)
        let pdf = try #require(PDFDocument(data: data))
        let firstPageText = pdf.page(at: 0)?.string ?? ""
        #expect(!firstPageText.contains("Revenue chart"))
        #endif
    }
}

private func makePNGData() throws -> Data {
    let width = 8
    let height = 8
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = try #require(
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )

    context.setFillColor(CGColor(red: 0.12, green: 0.58, blue: 0.84, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(
        CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}
