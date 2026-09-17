import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// 0...1
    let progress: Double

    var isUnlocked: Bool { progress >= 1 }
}

/// Badges derived from saved data, so nothing extra needs to be stored.
enum AchievementCatalog {
    static func evaluate(sessions: [ExerciseSession], scans: [FaceScan], blinkTests: [BlinkTest],
                         challengeHighScore: Int) -> [Achievement] {
        let totalReps = Double(sessions.totalReps)
        let bestStreak = Double(sessions.bestStreak)
        let bestScore = scans.map(\.overallScore).max() ?? 0
        let bestSymmetry = scans.map(\.symmetryScore).max() ?? 0
        let categoriesTrained = Double(Set(sessions.map(\.categoryRaw)).count)
        let bestEyeScore = blinkTests.map(\.score).max() ?? 0

        let chronological = scans.sorted { $0.date < $1.date }
        var improvement = 0.0
        if let first = chronological.first, let laterBest = chronological.dropFirst().map(\.overallScore).max() {
            improvement = laterBest - first.overallScore
        }

        func ratio(_ value: Double, _ goal: Double) -> Double {
            min(1, max(0, value) / goal)
        }

        return [
            Achievement(id: "first-workout", title: "First Rep", detail: "Complete your first exercise",
                        symbol: "figure.mind.and.body", progress: ratio(Double(sessions.count), 1)),
            Achievement(id: "streak-3", title: "Warming Up", detail: "Train 3 days in a row",
                        symbol: "flame", progress: ratio(bestStreak, 3)),
            Achievement(id: "streak-7", title: "Week Strong", detail: "Train 7 days in a row",
                        symbol: "flame.fill", progress: ratio(bestStreak, 7)),
            Achievement(id: "streak-30", title: "Habit Formed", detail: "Train 30 days in a row",
                        symbol: "calendar", progress: ratio(bestStreak, 30)),
            Achievement(id: "reps-100", title: "Century", detail: "Complete 100 reps",
                        symbol: "repeat", progress: ratio(totalReps, 100)),
            Achievement(id: "reps-1000", title: "Thousand Club", detail: "Complete 1,000 reps",
                        symbol: "repeat.circle.fill", progress: ratio(totalReps, 1000)),
            Achievement(id: "explorer", title: "Explorer", detail: "Train every muscle group",
                        symbol: "map", progress: ratio(categoriesTrained, Double(ExerciseCategory.allCases.count))),
            Achievement(id: "first-scan", title: "Baseline", detail: "Take your first face scan",
                        symbol: "faceid", progress: ratio(Double(scans.count), 1)),
            Achievement(id: "score-75", title: "Strong Face", detail: "Reach a Face Score of 75",
                        symbol: "bolt.fill", progress: ratio(bestScore, 75)),
            Achievement(id: "score-90", title: "Elite Face", detail: "Reach a Face Score of 90",
                        symbol: "crown.fill", progress: ratio(bestScore, 90)),
            Achievement(id: "symmetry-85", title: "Balanced", detail: "Score 85 for symmetry",
                        symbol: "circle.lefthalf.filled", progress: ratio(bestSymmetry, 85)),
            Achievement(id: "improver", title: "Improver", detail: "Raise your Face Score by 10 points",
                        symbol: "chart.line.uptrend.xyaxis", progress: ratio(improvement, 10)),
            Achievement(id: "challenge-1500", title: "Expression Master", detail: "Score 1,500 in Face Challenge",
                        symbol: "theatermasks.fill", progress: ratio(Double(challengeHighScore), 1500)),
            Achievement(id: "clear-eyes", title: "Clear Eyes", detail: "Score 80 in the eye comfort test",
                        symbol: "eye", progress: ratio(bestEyeScore, 80)),
        ]
    }
}
