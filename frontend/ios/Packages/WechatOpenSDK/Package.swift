// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WechatOpenSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "WechatOpenSDK",
            targets: ["WechatOpenSDK"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "WechatOpenSDK",
            path: "../../Frameworks/WechatOpenSDK.xcframework"
        )
    ]
)
