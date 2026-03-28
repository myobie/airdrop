// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "airdrop",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "airdrop", targets: ["airdrop"]),
    ],
    targets: [
        .executableTarget(
            name: "airdrop"
        ),
    ]
)
