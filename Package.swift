// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnalyticsKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "AnalyticsKit", targets: ["AnalyticsKit"]),
        .library(name: "AnalyticsKitFirebase", targets: ["AnalyticsKitFirebase"]),
        .library(name: "AnalyticsKitAdKit", targets: ["AnalyticsKitAdKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "13.0.0"),
        .package(url: "https://github.com/nangnguyendev/Ads.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "AnalyticsKit"),
        .target(
            name: "AnalyticsKitFirebase",
            dependencies: [
                "AnalyticsKit",
                .product(name: "FirebaseCore", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS]))
            ]
        ),
        .target(
            name: "AnalyticsKitAdKit",
            dependencies: [
                "AnalyticsKit",
                .product(name: "AdKit", package: "Ads")
            ]
        ),
        .testTarget(name: "AnalyticsKitTests", dependencies: ["AnalyticsKit"]),
        .testTarget(name: "AnalyticsKitAdKitTests", dependencies: ["AnalyticsKitAdKit"])
    ]
)
