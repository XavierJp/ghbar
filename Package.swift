// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "GHBar",
  platforms: [.macOS(.v14)],
  targets: [
    .executableTarget(
      name: "GHBar",
      path: "Sources/GHBar",
      swiftSettings: [.enableUpcomingFeature("BareSlashRegexLiterals")]
    )
  ]
)
