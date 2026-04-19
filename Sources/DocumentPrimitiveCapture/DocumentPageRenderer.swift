import Foundation
import SwiftUI

#if os(macOS)
import Ansel

/// Renders document pages to PNG using AnselViewRenderer for offscreen SwiftUI-to-image capture.
public struct DocumentPageRenderer: Sendable {
    public init() {}

    /// Renders a document page view to PNG data at the given size and scale.
    ///
    /// - Parameters:
    ///   - pageView: The SwiftUI view representing the document page.
    ///   - size: The point size to render at (e.g. letter page dimensions).
    ///   - scale: The backing scale factor. Defaults to 2.0 for retina output.
    /// - Returns: PNG-encoded image data.
    @MainActor
    public static func renderPage(
        _ pageView: some View,
        size: CGSize,
        scale: Double = 2.0
    ) throws -> Data {
        let screenshot = try AnselViewRenderer.render(
            pageView,
            size: size,
            scale: scale
        )
        return screenshot.pngData
    }

    /// Renders a document page view as a thumbnail at a smaller size.
    ///
    /// - Parameters:
    ///   - pageView: The SwiftUI view representing the document page.
    ///   - thumbnailSize: The point size for the thumbnail (e.g. 150x200).
    ///   - scale: The backing scale factor. Defaults to 2.0 for retina output.
    /// - Returns: PNG-encoded thumbnail image data.
    @MainActor
    public static func renderThumbnail(
        _ pageView: some View,
        thumbnailSize: CGSize,
        scale: Double = 2.0
    ) throws -> Data {
        let screenshot = try AnselViewRenderer.render(
            pageView,
            size: thumbnailSize,
            scale: scale
        )
        return screenshot.pngData
    }
}
#endif
