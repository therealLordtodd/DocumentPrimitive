// swift-tools-version: 6.0

import Foundation
import PackageDescription

private let anselDependency: Package.Dependency = {
    let localPath = "../Ansel"
    let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: dir.appendingPathComponent(localPath).path) {
        return .package(path: localPath)
    }
    return .package(url: "https://github.com/therealLordtodd/Ansel.git", branch: "main")
}()

private let marpleDependency: Package.Dependency = {
    let localPath = "../Marple"
    let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: dir.appendingPathComponent(localPath).path) {
        return .package(path: localPath)
    }
    return .package(url: "https://github.com/therealLordtodd/Marple.git", branch: "main")
}()

let package = Package(
    name: "DocumentPrimitive",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: [
        .library(name: "DocumentPrimitive", targets: ["DocumentPrimitive"]),
        .library(name: "DocumentPrimitiveGrid", targets: ["DocumentPrimitiveGrid"]),
        .library(name: "DocumentPrimitiveExport", targets: ["DocumentPrimitiveExport"]),
        .library(name: "DocumentPrimitivePreview", targets: ["DocumentPrimitivePreview"]),
        .library(name: "DocumentPrimitiveCapture", targets: ["DocumentPrimitiveCapture"]),
        .library(name: "DocumentPrimitiveMarple", targets: ["DocumentPrimitiveMarple"]),
    ],
    dependencies: [
        .package(path: "../RichTextPrimitive"),
        .package(path: "../PaginationPrimitive"),
        .package(path: "../GridPrimitive"),
        .package(path: "../DragAndDropPrimitive"),
        .package(path: "../FilterPrimitive"),
        .package(path: "../SearchPrimitive"),
        .package(path: "../BadgePrimitive"),
        .package(path: "../HoverBadgePrimitive"),
        .package(path: "../FilePreviewPrimitive"),
        .package(path: "../RulerPrimitive"),
        .package(path: "../CommentPrimitive"),
        .package(path: "../TrackChangesPrimitive"),
        .package(path: "../BookmarkPrimitive"),
        .package(path: "../ExportKit"),
        anselDependency,
        marpleDependency,
    ],
    targets: [
        .target(
            name: "DocumentPrimitive",
            dependencies: [
                .product(name: "RichTextPrimitive", package: "RichTextPrimitive"),
                .product(name: "PaginationPrimitive", package: "PaginationPrimitive"),
                .product(name: "DragAndDropPrimitive", package: "DragAndDropPrimitive"),
                .product(name: "FilterPrimitive", package: "FilterPrimitive"),
                .product(name: "SearchPrimitive", package: "SearchPrimitive"),
                .product(name: "BadgePrimitive", package: "BadgePrimitive"),
                .product(name: "HoverBadgePrimitive", package: "HoverBadgePrimitive"),
                .product(name: "RulerPrimitive", package: "RulerPrimitive"),
                .product(name: "CommentPrimitive", package: "CommentPrimitive"),
                .product(name: "TrackChangesPrimitive", package: "TrackChangesPrimitive"),
                .product(name: "BookmarkPrimitive", package: "BookmarkPrimitive"),
            ]
        ),
        .target(
            name: "DocumentPrimitiveGrid",
            dependencies: [
                "DocumentPrimitive",
                .product(
                    name: "GridPrimitive",
                    package: "GridPrimitive",
                    condition: .when(platforms: [.macOS])
                ),
                .product(
                    name: "GridPrimitiveTable",
                    package: "GridPrimitive",
                    condition: .when(platforms: [.macOS])
                ),
            ]
        ),
        .target(
            name: "DocumentPrimitiveExport",
            dependencies: [
                "DocumentPrimitive",
                .product(name: "ExportKit", package: "ExportKit"),
                .product(name: "PaginationPrimitive", package: "PaginationPrimitive"),
            ]
        ),
        .target(
            name: "DocumentPrimitivePreview",
            dependencies: [
                "DocumentPrimitive",
                .product(name: "RichTextPrimitive", package: "RichTextPrimitive"),
                .product(name: "FilePreviewPrimitive", package: "FilePreviewPrimitive"),
            ]
        ),
        .target(
            name: "DocumentPrimitiveCapture",
            dependencies: [
                "DocumentPrimitive",
                .product(name: "Ansel", package: "Ansel"),
            ]
        ),
        .target(
            name: "DocumentPrimitiveMarple",
            dependencies: [
                "DocumentPrimitive",
                .product(name: "MarpleCore", package: "Marple"),
            ]
        ),
        .testTarget(
            name: "DocumentPrimitiveTests",
            dependencies: [
                "DocumentPrimitive",
                .product(name: "BookmarkPrimitive", package: "BookmarkPrimitive"),
                .product(name: "CommentPrimitive", package: "CommentPrimitive"),
                .product(name: "FilterPrimitive", package: "FilterPrimitive"),
                .product(name: "SearchPrimitive", package: "SearchPrimitive"),
                .product(name: "TrackChangesPrimitive", package: "TrackChangesPrimitive"),
            ]
        ),
        .testTarget(
            name: "DocumentPrimitiveGridTests",
            dependencies: ["DocumentPrimitiveGrid", "DocumentPrimitive"]
        ),
        .testTarget(
            name: "DocumentPrimitiveExportTests",
            dependencies: ["DocumentPrimitiveExport", "DocumentPrimitive", .product(name: "ExportKit", package: "ExportKit")]
        ),
        .testTarget(
            name: "DocumentPrimitivePreviewTests",
            dependencies: ["DocumentPrimitivePreview", "DocumentPrimitive", .product(name: "RichTextPrimitive", package: "RichTextPrimitive")]
        ),
    ]
)
