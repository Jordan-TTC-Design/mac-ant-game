// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GoblinCamp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "GoblinCamp", path: "Sources/GoblinCamp")
    ]
)
