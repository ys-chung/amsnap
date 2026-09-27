import AppKit
import ArgumentParser
import MapKit

extension MapStyle: ExpressibleByArgument {}

@main
struct AMSnap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "amsnap",
        abstract: "Render an Apple Maps area to a PNG.",
        discussion: """
        Styles: standard, muted, transit, driving (experimental), light (experimental).
        transit/driving/light use undocumented MapKit map types and may break in future macOS releases.

        Example:
          amsnap --lat 22.2819 --lon 114.1580 --zoom 15 --type transit -o central.png
        """
    )

    @Option(help: "Centre latitude in degrees.")
    var lat: Double

    @Option(help: "Centre longitude in degrees.")
    var lon: Double

    @Option(help: "Web-Mercator zoom level, 0–20. Fractions allowed.")
    var zoom: Double

    @Option(name: [.customShort("t"), .long], help: "Map style.")
    var type: MapStyle = .standard

    @Option(help: ArgumentHelp("Raw MKMapType value; overrides --type. For exploring private styles.", visibility: .hidden))
    var rawMapType: UInt?

    @Option(help: "Output width in points.")
    var width: Double = 1024

    @Option(help: "Output height in points.")
    var height: Double = 1024

    @Option(help: "Pixels per point in the output PNG.")
    var scale: Double = 2

    @Flag(help: "Render in dark mode.")
    var dark = false

    @Flag(name: .customLong("no-poi"), help: "Hide points of interest.")
    var hidePointsOfInterest = false

    @Option(name: [.short, .long], help: "Output PNG path.")
    var output: String = "map.png"

    @Flag(help: "Keep MapKit's internal debug output.")
    var verbose = false

    func validate() throws {
        guard (-85.05112878...85.05112878).contains(lat) else {
            throw ValidationError("--lat must be within ±85.0511 (Web-Mercator limit).")
        }
        guard (-180...180).contains(lon) else { throw ValidationError("--lon must be within ±180.") }
        guard (0...20).contains(zoom) else { throw ValidationError("--zoom must be within 0–20.") }
        guard width >= 1, height >= 1 else { throw ValidationError("--width and --height must be ≥ 1.") }
        guard scale > 0, scale <= 4 else { throw ValidationError("--scale must be within (0, 4].") }
        guard width * scale <= 8192, height * scale <= 8192 else {
            throw ValidationError("Output must be at most 8192 px per side.")
        }
    }

    @MainActor
    func run() async throws {
        // MapKit needs an AppKit application object to render off-screen.
        _ = NSApplication.shared

        let request = SnapshotRequest(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            zoom: zoom,
            size: CGSize(width: width, height: height),
            scale: scale,
            mapTypeRawValue: rawMapType ?? type.mapTypeRawValue,
            dark: dark,
            showsPointsOfInterest: !hidePointsOfInterest
        )

        let silencer = verbose ? nil : OutputSilencer()
        let png: Data
        do {
            defer { silencer?.restore() }
            png = try await renderPNG(request)
        }

        let url = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
        try png.write(to: url)
        print(url.path)
    }
}

/// Redirects stdout/stderr to /dev/null; VectorKit prints tessellation debug spam to both.
final class OutputSilencer {
    private let saved: [(fd: Int32, copy: Int32)]

    init() {
        fflush(stdout)
        fflush(stderr)
        let devNull = open("/dev/null", O_WRONLY)
        saved = [STDOUT_FILENO, STDERR_FILENO].map { fd in
            let copy = dup(fd)
            dup2(devNull, fd)
            return (fd, copy)
        }
        close(devNull)
    }

    func restore() {
        fflush(stdout)
        fflush(stderr)
        for (fd, copy) in saved {
            dup2(copy, fd)
            close(copy)
        }
    }
}
