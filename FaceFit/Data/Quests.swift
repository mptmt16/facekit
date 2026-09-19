import Foundation

/// A goal for today, worth bonus XP. Progress is read from saved history,
/// so quests can never get out of sync with what you actually did.
struct DailyQuest: Identifiable {
    enum Goal {
        case reps(Int)
        case exercises(Int)
        case xp(Int)
        case category(ExerciseCategory, reps: Int)
        case scan
        case challenge
        case eyeTest
        case perfectForm(Int)
    }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    let reward: Int
    let goal: Goal

    var target: Double {
        switch goal {
        case .reps(let count): Double(count)
        case .exercises(let count): Double(count)
        case .xp(let amount): Double(amount)
        case .category(_, let reps): Double(reps)
        case .scan, .challenge, .eyeTest: 1
        case .perfectForm(let count): Double(count)
        }
    }
}

struct QuestProgress: Identifiable {
    let quest: DailyQuest
    let current: Double

    var id: String { quest.id }
    var fraction: Double { Swift.min(1, current / Swift.max(1, quest.target)) }
    var isComplete: Bool { current >= quest.target }
}

enum DailyQuests {
    /// Three quests for the given day, stable for the whole day.
    static func quests(for date: Date, playerLevel: Int) -> [DailyQuest] {
        let pool = pool(playerLevel: playerLevel)
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        guard pool.count >= 3 else { return pool }
        var chosen: [DailyQuest] = []
        var index = day % pool.count
        while chosen.count < 3 {
            let quest = pool[index % pool.count]
            if !chosen.contains(where: { $0.id == quest.id }) {
                chosen.append(quest)
            }
            index += 1
        }
        return chosen
    }

    static func progress(for quests: [DailyQuest], on day: Date, sessions: [ExerciseSession],
                         scans: [FaceScan], blinkTests: [BlinkTest]) -> [QuestProgress] {
        let calendar = Calendar.current
        let todaysSessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let todaysScans = scans.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let todaysTests = blinkTests.filter { calendar.isDate($0.date, inSameDayAs: day) }

        return quests.map { quest in
            let current: Double
            switch quest.goal {
            case .reps(_):
                current = Double(todaysSessions.reduce(0) { $0 + $1.repsCompleted })
            case .exercises(_):
                current = Double(todaysSessions.filter { $0.repsCompleted > 0 }.count)
            case .xp(_):
                current = Double(Progression.xpEarned(on: day, sessions: sessions, scans: scans, blinkTests: blinkTests))
            case .category(let category, _):
                current = Double(todaysSessions
                    .filter { $0.categoryRaw == category.rawValue }
                    .reduce(0) { $0 + $1.repsCompleted })
            case .scan:
                current = todaysScans.isEmpty ? 0 : 1
            case .challenge:
                // The challenge has no history of its own, so this one is marked done by the game itself.
                current = 0
            case .eyeTest:
                current = todaysTests.isEmpty ? 0 : 1
            case .perfectForm(_):
                current = Double(todaysSessions.filter { $0.intensity >= 1 }.reduce(0) { $0 + $1.repsCompleted })
            }
            return QuestProgress(quest: quest, current: current)
        }
    }

    /// Bonus XP from quests finished today.
    static func bonusXP(_ progress: [QuestProgress]) -> Int {
        progress.filter(\.isComplete).reduce(0) { $0 + $1.quest.reward }
    }

    private static func pool(playerLevel: Int) -> [DailyQuest] {
        var quests: [DailyQuest] = [
            DailyQuest(id: "reps-30", title: "Warm up", detail: "Complete 30 reps today",
                       symbol: "repeat", reward: 40, goal: .reps(30)),
            DailyQuest(id: "reps-60", title: "Full session", detail: "Complete 60 reps today",
                       symbol: "flame", reward: 70, goal: .reps(60)),
            DailyQuest(id: "exercises-3", title: "Mix it up", detail: "Finish 3 different exercises",
                       symbol: "square.grid.2x2", reward: 50, goal: .exercises(3)),
            DailyQuest(id: "xp-200", title: "Earn 200 XP", detail: "Any training counts",
                       symbol: "star.fill", reward: 60, goal: .xp(200)),
            DailyQuest(id: "form-15", title: "Perfect form", detail: "15 reps at full target strength",
                       symbol: "checkmark.seal", reward: 60, goal: .perfectForm(15)),
            DailyQuest(id: "scan", title: "Track your face", detail: "Take a face scan",
                       symbol: "faceid", reward: 80, goal: .scan),
            DailyQuest(id: "eye-test", title: "Rest your eyes", detail: "Run the eye comfort test",
                       symbol: "eye", reward: 50, goal: .eyeTest),
        ]

        // Category quests only appear once the matching exercises are unlocked.
        let unlocked = Progression.unlocked(playerLevel: playerLevel)
        for category in ExerciseCategory.allCases where unlocked.contains(where: { $0.category == category }) {
            quests.append(DailyQuest(id: "category-\(category.rawValue)",
                                     title: category.title,
                                     detail: "Complete 20 reps for \(category.title.lowercased())",
                                     symbol: category.symbol,
                                     reward: 55,
                                     goal: .category(category, reps: 20)))
        }
        return quests
    }
}
