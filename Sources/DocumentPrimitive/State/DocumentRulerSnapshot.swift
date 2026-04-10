import Foundation
import RulerPrimitive

public struct DocumentRulerSnapshot: Sendable, Equatable {
    public var configuration: RulerConfiguration
    public var markers: [RulerMarkerItem]

    public init(
        configuration: RulerConfiguration,
        markers: [RulerMarkerItem]
    ) {
        self.configuration = configuration
        self.markers = markers
    }

    public func marker(ofType markerType: RulerMarkerType) -> RulerMarkerItem? {
        markers.first { $0.markerType == markerType }
    }
}
