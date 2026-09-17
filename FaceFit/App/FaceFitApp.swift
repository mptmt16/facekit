import SwiftUI
import SwiftData

@main
struct FaceFitApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(for: [ExerciseSession.self, FaceScan.self])
    }
}

enum SettingsKey {
    static let voiceCoach = "voiceCoach"
    static let haptics = "haptics"
    static let showMesh = "showMesh"
    static let difficulty = "difficulty"
    static let hasOnboarded = "hasOnboarded"
}
