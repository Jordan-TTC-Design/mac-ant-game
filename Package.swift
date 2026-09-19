// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AntFarm",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "AntFarm", path: "Sources/AntFarm")
    ]
)
