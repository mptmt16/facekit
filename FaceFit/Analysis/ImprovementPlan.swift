import Foundation

/// A personal routine that targets the weakest areas of the latest scan plus the user's goals.
struct ImprovementPlan {
    struct Item: Identifiable {
        let exercise: Exercise
        /// Nil for the relaxation cool-down.
        let region: FaceRegion?

        var id: String { exercise.id }
    }

    let focus: [FaceRegion]
    let items: [Item]

    var exercises: [Exercise] { items.map(\.exercise) }

    var duration: TimeInterval {
        items.reduce(0) { $0 + $1.exercise.estimatedDuration }
    }

    /// - Parameters:
    ///   - scores: per-area scores from the latest scan (empty if the user hasn't scanned).
    ///   - goals: areas the user wants to improve; they get extra priority.
    static func build(scores: [RegionScore], goals: Set<FaceRegion>) -> ImprovementPlan {
        var need: [FaceRegion: Double] = [:]
        for item in scores {
            guard let score = item.score else { continue }
            need[item.region] = 100 - score
        }
        for goal in goals {
            need[goal, default: 0] += 25
        }

        // Only areas with real room to improve, or that the user chose, make the plan.
        let focus = need
            .filter { $0.value >= 15 || goals.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }

        var items: [Item] = []
        var used = Set<String>()
        for region in focus {
            var added = 0
            for id in region.exerciseIDs {
                guard added < 2, !used.contains(id), let exercise = ExerciseLibrary.exercise(id: id) else { continue }
                items.append(Item(exercise: exercise.with(reps: Swift.min(exercise.reps, 6)), region: region))
                used.insert(id)
                added += 1
            }
        }

        if !items.isEmpty, !used.contains("soft-face"), let coolDown = ExerciseLibrary.exercise(id: "soft-face") {
            items.append(Item(exercise: coolDown.with(reps: 2), region: nil))
        }
        return ImprovementPlan(focus: Array(focus), items: items)
    }
}
