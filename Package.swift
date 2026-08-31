// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BookBurner",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "BookBurnerDomain",
            targets: ["BookBurner"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BookBurner",
            path: "BookBurner"
        ),
        .testTarget(
            name: "BookBurnerTests",
            dependencies: ["BookBurner"],
            path: "Tests/BookBurnerTests"
        ),
    ]
)
