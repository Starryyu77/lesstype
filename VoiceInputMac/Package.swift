// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceInputMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VoiceInputMac", targets: ["VoiceInputMac"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceInputMac",
            path: "VoiceInputMac",
            resources: [
                .process("Prompts"),
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "VoiceInputMacTests",
            dependencies: ["VoiceInputMac"],
            path: "Tests",
            resources: [
                .copy("prompt_cases.yaml"),
                .copy("dictionary_cases.yaml")
            ]
        )
    ]
)
