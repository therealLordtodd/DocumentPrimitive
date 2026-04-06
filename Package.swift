// swift-tools-version: 6.0

import PackageDescription

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
    ],
    dependencies: [
        .package(path: "../RichTextPrimitive"),
        .package(path: "../PaginationPrimitive"),
        .package(path: "../GridPrimitive"),
        .package(path: "../DragAndDropPrimitive"),
        .package(path: "../FilterPrimitive"),
        .package(path: "../RulerPrimitive"),
        .package(path: "../CommentPrimitive"),
        .package(path: "../TrackChangesPrimitive"),
        .package(path: "../BookmarkPrimitive"),
        .package(path: "../ExportKit"),
    ],
    targets: [
        .target(
            name: "DocumentPrimitive",
            dependencies: [
                .product(name: "RichTextPrimitive", package: "RichTextPrimitive"),
                .product(name: "PaginationPrimitive", package: "PaginationPrimitive"),
                .product(name: "DragAndDropPrimitive", package: "DragAndDropPrimitive"),
                .product(name: "FilterPrimitive", package: "FilterPrimitive"),
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
        .testTarget(
            name: "DocumentPrimitiveTests",
            dependencies: [
                "DocumentPrimitive",
                .product(name: "BookmarkPrimitive", package: "BookmarkPrimitive"),
                .product(name: "CommentPrimitive", package: "CommentPrimitive"),
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
    ]
)
