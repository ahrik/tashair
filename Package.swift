// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TashAir", defaultLocalization: "ru", platforms: [.macOS(.v14)],
    products: [.library(name: "TashAirCore", targets: ["TashAirCore"]), .executable(name: "TashAir", targets: ["TashAir"]), .executable(name: "TashAirWidgetPreview", targets: ["TashAirWidgetPreview"])],
    targets: [
        .target(name: "TashAirCore"),
        .executableTarget(name: "TashAir", dependencies: ["TashAirCore"]),
        .executableTarget(name: "TashAirWidgetPreview", dependencies: ["TashAirCore"], path: "Sources/TashAirWidgets", swiftSettings: [.define("WIDGET_PREVIEW")]),
        .testTarget(name: "TashAirCoreTests", dependencies: ["TashAirCore"])
    ]
)
