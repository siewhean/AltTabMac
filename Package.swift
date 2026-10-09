// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CmdTab",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.2"
        )
    ],
    targets: [
        .executableTarget(
            name: "CmdTab",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CmdTab",
            exclude: [
                // The production app uses ProfileHotkeyManager. Shared state
                // models now live in HotkeyStateModels.swift so the retired
                // legacy router cannot reintroduce permissive modifier taps.
                "HotkeyManager.swift"
            ]
        ),
        .testTarget(
            name: "CmdTabTests",
            dependencies: ["CmdTab"],
            path: "Tests/CmdTabTests"
        )
    ]
)
