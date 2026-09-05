// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "shared-buddy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BuddyCore", targets: ["BuddyCore"]),
        .library(name: "BuddyUI", targets: ["BuddyUI"]),
        .library(name: "BuddyFirebase", targets: ["BuddyFirebase"]),
        .library(name: "BuddyLocalization", targets: ["BuddyLocalization"]),
        .library(name: "BuddyTesting", targets: ["BuddyTesting"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.18.0")
    ],
    targets: [
        .target(
            name: "BuddyCore",
            path: "Sources/BuddyCore"
        ),
        .target(
            name: "BuddyUI",
            dependencies: ["BuddyCore", "BuddyLocalization"],
            path: "Sources/BuddyUI"
        ),
        .target(
            name: "BuddyFirebase",
            dependencies: [
                "BuddyCore",
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk")
            ],
            path: "Sources/BuddyFirebase"
        ),
        .target(
            name: "BuddyLocalization",
            path: "Sources/BuddyLocalization",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "BuddyTesting",
            dependencies: ["BuddyCore"],
            path: "Sources/BuddyTesting"
        ),
        .testTarget(
            name: "BuddyCoreTests",
            dependencies: ["BuddyCore", "BuddyTesting", "BuddyLocalization"],
            path: "Tests/BuddyCoreTests"
        )
    ]
)
