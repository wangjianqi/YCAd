// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YCAd",
    platforms: [.iOS("17.6")],
    products: [
        .library(name: "YCAd", targets: ["YCAd"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "13.0.0"
        ),
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
            from: "3.0.0"
        ),
    ],
    targets: [
        .target(
            name: "YCAd",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "UserMessagingPlatform", package: "swift-package-manager-google-user-messaging-platform"),
            ]
        ),
        .testTarget(
            name: "YCAdTests",
            dependencies: ["YCAd"]
        ),
    ],
    swiftLanguageVersions: [.v6]
)
