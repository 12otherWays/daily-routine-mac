// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DailyRoutine",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DailyRoutineApp",
            path: "Sources/DailyRoutineApp"
        ),
        .testTarget(
            name: "DailyRoutineAppTests",
            dependencies: ["DailyRoutineApp"],
            path: "Tests/DailyRoutineAppTests"
        )
    ]
)
