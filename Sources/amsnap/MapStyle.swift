import MapKit

/// Map styles the CLI can render. Satellite/hybrid imagery is intentionally excluded.
enum MapStyle: String, CaseIterable, Sendable {
    case standard
    case muted
    case transit
    /// Road-emphasised style used by Maps' Driving mode. Private, experimental.
    case driving
    /// Washed-out low-contrast style. Private, experimental.
    case light

    /// The value assigned to `MKMapSnapshotter.Options.mapType`.
    ///
    /// Values >= 100 are undocumented. MapKit translates them into its internal
    /// cartographic configuration `{style, emphasis, …}`; probing on macOS 27 showed:
    ///   104 → emphasis 4 (transit lines, stations, ferry routes)
    ///   108 → emphasis 2 (driving)
    ///   109 → mapKitUsage 2 (light)
    /// Unknown values silently fall back to `.standard`.
    var mapTypeRawValue: UInt {
        switch self {
        case .standard: MKMapType.standard.rawValue
        case .muted: MKMapType.mutedStandard.rawValue
        case .transit: 104
        case .driving: 108
        case .light: 109
        }
    }

    var isPrivate: Bool { mapTypeRawValue >= 100 }
}
