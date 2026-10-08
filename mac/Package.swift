// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GoblinCamp",
    platforms: [.macOS(.v13)],
    targets: [
        // The camp's rules, the same as the server's (shared/src/camp): no AppKit, so the checker can use them too.
        .target(name: "CampRules", path: "Sources/CampRules"),
        // The guild hall's rules, the same as the phones' (shared/src/guild-hall.ts): no AppKit either, for its checker.
        .target(name: "GuildRules", path: "Sources/GuildRules"),
        .executableTarget(name: "GoblinCamp", dependencies: ["CampRules", "GuildRules"], path: "Sources/GoblinCamp"),
        // `swift run camp-rules-check`: works out shared/src/camp/fixtures.json again and says if anything differs.
        .executableTarget(name: "camp-rules-check", dependencies: ["CampRules"], path: "Sources/camp-rules-check"),
        // `swift run guild-rules-check`: works out shared/src/guild-hall-fixtures.json again and says if anything differs.
        .executableTarget(name: "guild-rules-check", dependencies: ["GuildRules"], path: "Sources/guild-rules-check"),
    ]
)
