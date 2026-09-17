import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var sessions: [ExerciseSession]
    @Query private var scans: [FaceScan]
    @Query private var blinkTests: [BlinkTest]
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0

    var body: some View {
        let achievements = AchievementCatalog.evaluate(sessions: sessions, scans: scans, blinkTests: blinkTests,
                                                       challengeHighScore: challengeHighScore)
        let unlocked = achievements.filter(\.isUnlocked).count

        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("\(unlocked) of \(achievements.count)")
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                    Text("achievements unlocked")
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(unlocked), total: Double(max(achievements.count, 1)))
                        .tint(Theme.warm)
                }
                .card()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(achievements) { achievement in
                        AchievementTile(achievement: achievement)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Achievements")
    }
}

struct AchievementTile: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 28))
                .foregroundStyle(achievement.isUnlocked ? Theme.warm : Color.white.opacity(0.3))
                .frame(width: 60, height: 60)
                .background((achievement.isUnlocked ? Theme.warm : Color.white).opacity(0.12), in: Circle())
            Text(achievement.title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            Text(achievement.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            if achievement.isUnlocked {
                Label("Unlocked", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.accent)
            } else {
                ProgressView(value: achievement.progress)
                    .tint(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
