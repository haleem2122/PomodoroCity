// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PomodoroCity",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PomodoroCity", path: "Sources/PomodoroCity"),
        .testTarget(name: "PomodoroCityTests", dependencies: ["PomodoroCity"], path: "Tests/PomodoroCityTests"),
    ]
)
