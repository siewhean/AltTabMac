// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CmdTab",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "CmdTab",
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
