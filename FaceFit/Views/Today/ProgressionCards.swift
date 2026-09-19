import SwiftUI

/// Level, XP bar and today's progress toward the daily goal.
struct PlayerLevelCard: View {
    let xp: Int
    let todayXP: Int
    let streak: Int

    var body: some View {
        let progress = Progression.progress(forXP: xp)
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: progress.fraction, lineWidth: 8, color: Theme.warm)
                    VStack(spacing: -2) {
                        Text("\(progress.level)")
                            .font(.title2.bold().monospacedDigit())
                        Text("LEVEL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Progression.rank(forLevel: progress.level))
                        .font(.title3.bold())
                        .foregroundStyle(Theme.warm)
                    Text("\(progress.remaining) XP to level \(progress.level + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let next = Progression.unlocks(atLevel: progress.level + 1).first {
                        Label("Next unlock: \(next.name)", systemImage: "lock.open")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(streak > 0 ? Theme.warm : Color.secondary)
                    Text("\(streak)")
                        .font(.headline.monospacedDigit())
                    Text("streak").font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Today")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(todayXP) / \(Progression.dailyGoalXP) XP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(todayXP >= Progression.dailyGoalXP ? Theme.accent : Color.secondary)
                }
                ProgressView(value: min(1, Double(todayXP) / Double(Progression.dailyGoalXP)))
                    .tint(todayXP >= Progression.dailyGoalXP ? Theme.accent : Theme.warm)
            }
        }
        .card()
    }
}

/// Today's three quests with live progress.
struct QuestsCard: View {
    let quests: [QuestProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Daily quests", subtitle: "Bonus XP for finishing them")
                Text("\(quests.filter(\.isComplete).count)/\(quests.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.warm)
            }
            ForEach(quests) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : item.quest.symbol)
                        .font(.headline)
                        .foregroundStyle(item.isComplete ? Theme.accent : Theme.secondary)
                        .frame(width: 32, height: 32)
                        .background((item.isComplete ? Theme.accent : Theme.secondary).opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.quest.title)
                                .font(.subheadline.weight(.semibold))
                                .strikethrough(item.isComplete)
                            Spacer()
                            Text("+\(item.quest.reward) XP")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.warm)
                        }
                        Text(item.quest.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !item.isComplete {
                            ProgressView(value: item.fraction)
                                .tint(Theme.secondary)
                        }
                    }
                }
            }
        }
        .card()
    }
}

/// Stars earned on one exercise.
struct MasteryStars: View {
    let mastery: Progression.Mastery
    var compact = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { star in
                Image(systemName: star <= mastery.rawValue ? "star.fill" : "star")
                    .font(compact ? .system(size: 9) : .caption2)
                    .foregroundStyle(star <= mastery.rawValue ? Theme.warm : Color.white.opacity(0.25))
            }
        }
    }
}
