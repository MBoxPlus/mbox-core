// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MBoxCore",
    products: [
        .executable(name: "MBoxCLI", targets: ["MBoxCLI"]),
        .executable(name: "MDevCLI", targets: ["MDevCLI"]),
        .library(
            name: "MBoxCore",
            targets: ["MBoxCore"]
        )],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", .exact("4.8.2")),
        .package(url:"https://github.com/Kitura/BlueSignals",.exact("1.0.21")),
        .package(url:"https://github.com/jpsim/Yams",.exact("4.0.3"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(name: "MBoxCLI", dependencies: ["MBoxCore"], path: "Native/MBoxCLI"),
        .executableTarget(name: "MDevCLI", dependencies: ["MBoxCore"], path: "Native/MDevCLI"),
        .target(name: "MBoxCore", dependencies: ["Alamofire", "Yams", .product(name: "Signals", package: "BlueSignals")],
                path: "Native/MBoxCore",exclude: ["Info.plist","PluginManager/Commander/Autocompletion/mbox.sh","PluginManager/Commander/Autocompletion/mbox2.sh","PluginManager/Commander/Autocompletion/mdev.sh"])
    ]
)
