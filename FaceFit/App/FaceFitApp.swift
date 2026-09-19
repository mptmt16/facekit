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
        .modelContainer(for: [ExerciseSession.self, FaceScan.self, BlinkTest.self])
    }
}

enum SettingsKey {
    static let voiceCoach = "voiceCoach"
    static let haptics = "haptics"
    static let showMesh = "showMesh"
    static let difficulty = "difficulty"
    static let hasOnboarded = "hasOnboarded"
    static let reminderEnabled = "reminderEnabled"
    /// Reminder time as minutes after midnight.
    static let reminderMinutes = "reminderMinutes"
    static let challengeHighScore = "challengeHighScore"
    static let challengeGames = "challengeGames"
    /// Comma-separated FaceRegion raw values.
    static let improvementGoals = "improvementGoals"
    static let saveFacePhoto = "saveFacePhoto"
    /// Comma-separated exercise ids.
    static let favouriteExercises = "favouriteExercises"
}
