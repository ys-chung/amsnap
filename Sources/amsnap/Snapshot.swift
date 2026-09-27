import AppKit
import MapKit

struct SnapshotRequest: Sendable {
    var center: CLLocationCoordinate2D
    /// Web-Mercator zoom level (0 = whole world in 256 pt, each +1 doubles scale). Fractions allowed.
    var zoom: Double
    /// Output size in points.
    var size: CGSize
    /// Pixels per point.
    var scale: Double
    /// `MKMapType` raw value, possibly a private one.
    var mapTypeRawValue: UInt
    var dark: Bool
    var showsPointsOfInterest: Bool
}

enum SnapshotError: Error, CustomStringConvertible {
    case encodeFailed

    var description: String {
        switch self {
        case .encodeFailed: "failed to encode PNG"
        }
    }
}

/// `MKMapRect` whose centre is `center` and which, drawn at `size` points, has the given zoom.
///
/// MapKit's world is `MKMapSize.world` = 256 · 2^20 map points wide, i.e. zoom 20 is
/// one map point per screen point, so every zoom step below 20 doubles the points per pixel.
func mapRect(center: CLLocationCoordinate2D, zoom: Double, size: CGSize) -> MKMapRect {
    let pointsPerScreenPoint = pow(2, 20 - zoom)
    let width = size.width * pointsPerScreenPoint
    let height = size.height * pointsPerScreenPoint
    let mid = MKMapPoint(center)
    return MKMapRect(x: mid.x - width / 2, y: mid.y - height / 2, width: width, height: height)
}

@MainActor
func renderPNG(_ request: SnapshotRequest) async throws -> Data {
    let options = MKMapSnapshotter.Options()
    options.mapRect = mapRect(center: request.center, zoom: request.zoom, size: request.size)
    options.size = request.size
    options.mapType = MKMapType(rawValue: request.mapTypeRawValue) ?? .standard
    options.appearance = NSAppearance(named: request.dark ? .darkAqua : .aqua)
    if !request.showsPointsOfInterest {
        options.pointOfInterestFilter = .excludingAll
    }

    let snapshot = try await MKMapSnapshotter(options: options).start()

    // Snapshots come back at the main screen's backing scale; redraw into an exact pixel grid.
    let pixelsWide = Int((request.size.width * request.scale).rounded())
    let pixelsHigh = Int((request.size.height * request.scale).rounded())
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelsWide,
        pixelsHigh: pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw SnapshotError.encodeFailed }
    rep.size = request.size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    snapshot.image.draw(in: NSRect(origin: .zero, size: request.size))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw SnapshotError.encodeFailed
    }
    return png
}
