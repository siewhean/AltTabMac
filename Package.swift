// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AltTabMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AltTabMac",
            path: "Sources/AltTabMac"
        ),
        .testTarget(
            name: "AltTabMacTests",
            dependencies: ["AltTabMac"],
            path: "Tests/AltTabMacTests"
        )
    ]
)
