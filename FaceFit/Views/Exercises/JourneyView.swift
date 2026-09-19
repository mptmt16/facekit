import SwiftUI
import SwiftData

/// The unlock path: every level, what it unlocks, and how far along you are.
struct JourneyView: View {
    @Query private var sessions: [ExerciseSession]
    @Query private var scans: [FaceScan]
    @Query private var blinkTests: [BlinkTest]
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0
    @AppStorage(SettingsKey.challengeGames) private var challengeGames = 0

    private var xp: Int {
        Progression.totalXP(sessions: sessions, scans: scans, blinkTests: blinkTests,
                            challengeGames: challengeGames, challengeHighScore: challengeHighScore)
    }

    /// Levels worth showing: everything reached, plus the next few to aim at.
    private var levels: [Int] {
        let current = Progression.level(forXP: xp)
        let highestUnlock = Progression.unlockLevels.values.max() ?? 9
        return Array(1...Swift.max(current + 2, Swift.min(highestUnlock, current + 4)))
    }

    var body: some View {
        ScrollView {
            let progress = Progression.progress(forXP: xp)
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Level \(progress.level) · \(Progression.rank(forLevel: progress.level))")
                        .font(.title2.bold())
                    Text("\(progress.xp) XP total · \(progress.remaining) to the next level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: progress.fraction).tint(Theme.warm)
                }
                .card()
                .padding(.bottom, 8)

                ForEach(levels, id: \.self) { level in
                    stage(level: level, playerLevel: progress.level)
                }

                Text("XP comes from reps, finished exercises, scans, eye tests and the Face Challenge. Locked exercises stay out of your plan until you reach their level.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            .padding()
        }
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stage(level: Int, playerLevel: Int) -> some View {
        let reached = playerLevel >= level
        let isCurrent = playerLevel == level
        let unlocks = Progression.unlocks(atLevel: level)
        let programs = ProgramLibrary.all.filter { Progression.unlockLevel(forProgram: $0.id) == level }

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(reached ? Theme.warm : Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)
                    if reached {
                        Text("\(level)")
                            .font(.headline.bold())
                            .foregroundStyle(.black)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Theme.accent, lineWidth: isCurrent ? 3 : 0)
                        .frame(width: 54, height: 54)
                )
                Rectangle()
                    .fill(reached ? Theme.warm.opacity(0.5) : Color.white.opacity(0.12))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 54)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Level \(level)")
                        .font(.headline)
                    if isCurrent {
                        Text("YOU ARE HERE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.2), in: Capsule())
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    if !reached {
                        Text("\(Progression.xpRequired(forLevel: level)) XP")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if unlocks.isEmpty && programs.isEmpty {
                    Text(reached ? "Keep training to build your streak." : "Bonus XP milestone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(unlocks) { exercise in
                    HStack(spacing: 10) {
                        Image(systemName: reached ? exercise.symbol : "lock.fill")
                            .foregroundStyle(reached ? exercise.category.color : Color.secondary)
                            .frame(width: 28, height: 28)
                            .background((reached ? exercise.category.color : Color.white).opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(reached ? Color.primary : Color.secondary)
                            Text(exercise.category.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if reached {
                            MasteryStars(mastery: Progression.mastery(reps: Progression.reps(for: exercise.id, in: sessions)))
                        }
                    }
                }

                ForEach(programs) { program in
                    Label("\(program.name) program", systemImage: reached ? program.symbol : "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(reached ? program.color : Color.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card.opacity(reached ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.bottom, 12)
        }
    }
}
