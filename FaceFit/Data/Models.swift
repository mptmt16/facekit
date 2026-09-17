import Foundation
import SwiftData

@Model
final class ExerciseSession {
    var date: Date = Date()
    var exerciseID: String = ""
    var exerciseName: String = ""
    var categoryRaw: String = ""
    var repsCompleted: Int = 0
    var repsTarget: Int = 0
    var duration: Double = 0
    /// Mean activation while holding, relative to target (1.0 = on target).
    var intensity: Double = 0
    /// Mean left/right balance, 0...1.
    var symmetry: Double?

    init(result: ExerciseResult, date: Date = .now) {
        self.date = date
        exerciseID = result.exercise.id
        exerciseName = result.exercise.name
        categoryRaw = result.exercise.category.rawValue
        repsCompleted = result.repsCompleted
        repsTarget = result.exercise.reps
        duration = result.duration
        intensity = result.intensity
        symmetry = result.symmetry
    }

    var category: ExerciseCategory? { ExerciseCategory(rawValue: categoryRaw) }
}

@Model
final class FaceScan {
    var date: Date = Date()
    var overallScore: Double = 0
    var symmetryScore: Double = 0
    var rangeScore: Double = 0
    var relaxationScore: Double = 0
    var meshAsymmetryMM: Double?
    var eyeDistanceMM: Double?
    var faceWidthMM: Double?
    var faceHeightMM: Double?
    @Attribute(.externalStorage) var expressionsData: Data?
    @Attribute(.externalStorage) var tensionData: Data?
    @Attribute(.externalStorage) var meshData: Data?

    init(outcome: ScanOutcome, date: Date = .now) {
        self.date = date
        overallScore = outcome.overallScore
        symmetryScore = outcome.symmetryScore
        rangeScore = outcome.rangeScore
        relaxationScore = outcome.relaxationScore
        meshAsymmetryMM = outcome.meshAsymmetryMM
        eyeDistanceMM = outcome.eyeDistanceMM
        faceWidthMM = outcome.faceWidthMM
        faceHeightMM = outcome.faceHeightMM
        let encoder = JSONEncoder()
        expressionsData = try? encoder.encode(outcome.expressions)
        tensionData = try? encoder.encode(outcome.tension)
        meshData = outcome.mesh.flatMap { try? encoder.encode($0) }
    }

    var expressions: [ExpressionResult] {
        guard let expressionsData else { return [] }
        return (try? JSONDecoder().decode([ExpressionResult].self, from: expressionsData)) ?? []
    }

    var tension: [TensionItem] {
        guard let tensionData else { return [] }
        return (try? JSONDecoder().decode([TensionItem].self, from: tensionData)) ?? []
    }

    var mesh: MeshSnapshot? {
        guard let meshData else { return nil }
        return try? JSONDecoder().decode(MeshSnapshot.self, from: meshData)
    }

    /// The findings with the most room to improve, weakest first.
    var focusAreas: [String] {
        let weakExpressions = expressions
            .map { ($0.id, (1 - $0.rangeScore) + (1 - ($0.symmetry ?? 1))) }
            .filter { $0.1 > 0.25 }
        let tenseMuscles = tension
            .filter { $0.excess > 0.03 }
            .map { ($0.id, $0.excess * 4) }
        return (weakExpressions + tenseMuscles)
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
}

extension Array where Element == ExerciseSession {
    /// Consecutive days (ending today or yesterday) with at least one session.
    var streak: Int {
        let calendar = Calendar.current
        let days = Set(map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        var count = 0
        while days.contains(day), let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            count += 1
            day = previous
        }
        return count
    }
}
