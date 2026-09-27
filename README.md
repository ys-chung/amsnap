# amsnap

A macOS command-line tool that renders an area of Apple Maps to a PNG. It uses `MKMapSnapshotter` under the hood.

```sh
swift build -c release
.build/release/amsnap --lat 22.2819 --lon 114.1580 --zoom 15 --type transit -o central.png
```

## Options

| Option | Default | |
|---|---|---|
| `--lat`, `--lon` | required | Centre coordinate |
| `--zoom` | required | Web-Mercator zoom, 0–20 (fractions OK). Same scale as Google/OSM tiles: 256 pt = whole world at zoom 0 |
| `-t, --type` | `standard` | `standard`, `muted`, `transit`, `driving`*, `light`* |
| `--width`, `--height` | 1024 | Output size in points |
| `--scale` | 2 | Pixels per point. MapKit renders at the main screen's backing scale, so values above it are upsampled |
| `--dark` | off | Dark appearance |
| `--no-poi` | off | Hide points of interest (transit stations and lines stay) |
| `-o, --output` | `map.png` | Output path. The absolute path is printed on success |

\* experimental

## Private API

`muted` uses the public `MKMapType.mutedStandard`. The other non-standard styles set `MKMapSnapshotter.Options.mapType` to undocumented raw values. MapKit maps these onto its internal cartographic configuration:

| Style | `mapType` raw value | Effect |
|---|---|---|
| `transit` | 104 | Transit emphasis: rail lines, stations, ferry routes |
| `driving` | 108 | Road emphasis, as in Maps' Driving mode |
| `light` | 109 | Washed-out, low-contrast base |

These values were found by probing `MKMapSnapshotOptions._cartographicConfiguration` on macOS 27. If Apple changes them, an unknown value falls back to the standard map without raising an error. The hidden `--raw-map-type <n>` flag lets you try other values.

VectorKit prints tessellation debug output to stdout and stderr while it renders. `amsnap` silences both unless you pass `--verbose`.
