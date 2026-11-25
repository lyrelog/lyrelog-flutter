// swift-tools-version: 5.9
// The iOS half of the lyrelog Flutter plugin, a thin layer over the Lyrelog Swift SDK.
//
// The Swift SDK from its public repository, 1.1.1 (crashes caught in the app's own process) up to
// (not including) 2.0.0.
//
// There is no podspec (the Swift SDK has none): apps need Swift Package Manager on, Flutter's
// default since 3.44.

import Foundation
import PackageDescription

let lyrelogSwift: Package.Dependency = .package(
    url: "https://github.com/lyrelog/lyrelog-swift", "1.1.1"..<"2.0.0"
)

let package = Package(
    name: "lyrelog_ios",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "lyrelog-ios", targets: ["lyrelog_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        lyrelogSwift,
    ],
    targets: [
        .target(
            name: "lyrelog_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Lyrelog", package: "lyrelog-swift"),
            ]
        )
    ]
)
