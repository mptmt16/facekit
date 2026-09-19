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
    /// Nil for scans taken before the wink control test was added.
    var controlScore: Double?
    var meshAsymmetryMM: Double?
    var eyeDistanceMM: Double?
    var faceWidthMM: Double?
    var faceHeightMM: Double?
    @Attribute(.externalStorage) var expressionsData: Data?
    @Attribute(.externalStorage) var tensionData: Data?
    @Attribute(.externalStorage) var controlData: Data?
    @Attribute(.externalStorage) var meshData: Data?
    /// JPEG photo and JSON mesh for the color 3D face.
    @Attribute(.externalStorage) var textureImageData: Data?
    @Attribute(.externalStorage) var textureMeshData: Data?
    @Attribute(.externalStorage) var skinData: Data?

    init(outcome: ScanOutcome, date: Date = .now) {
        self.date = date
        overallScore = outcome.overallScore
        symmetryScore = outcome.symmetryScore
        rangeScore = outcome.rangeScore
        relaxationScore = outcome.relaxationScore
        controlScore = outcome.controlScore
        meshAsymmetryMM = outcome.meshAsymmetryMM
        eyeDistanceMM = outcome.eyeDistanceMM
        faceWidthMM = outcome.faceWidthMM
        faceHeightMM = outcome.faceHeightMM
        let encoder = JSONEncoder()
        expressionsData = try? encoder.encode(outcome.expressions)
        tensionData = try? encoder.encode(outcome.tension)
        controlData = try? encoder.encode(outcome.controls)
        meshData = outcome.mesh.flatMap { try? encoder.encode($0) }
        textureImageData = outcome.textureJPEG
        textureMeshData = outcome.texture.flatMap { try? encoder.encode($0) }
        skinData = outcome.skin.flatMap { try? encoder.encode($0) }
    }

    var skin: SkinReport? {
        guard let skinData else { return nil }
        return try? JSONDecoder().decode(SkinReport.self, from: skinData)
    }

    func setSkin(_ report: SkinReport) {
        skinData = try? JSONEncoder().encode(report)
    }

    var texture: FaceTexture? {
        guard let textureMeshData else { return nil }
        return try? JSONDecoder().decode(FaceTexture.self, from: textureMeshData)
    }

    var breakdown: FaceScoreBreakdown {
        FaceScoreBreakdown(symmetry: symmetryScore, mobility: rangeScore,
                           control: controlScore, relaxation: relaxationScore)
    }

    var level: FaceLevel { FaceLevel(score: overallScore) }

    var controls: [ControlResult] {
        guard let controlData else { return [] }
        return (try? JSONDecoder().decode([ControlResult].self, from: controlData)) ?? []
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
        let weakControl = controls
            .map { ($0.id, (1 - $0.score) * 1.5) }
            .filter { $0.1 > 0.3 }
        return (weakExpressions + tenseMuscles + weakControl)
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
}

@Model
final class BlinkTest {
    var date: Date = Date()
    var duration: Double = 0
    var blinkCount: Int = 0
    var partialBlinkCount: Int = 0
    var longestGap: Double = 0
    var openness: Double = 0
    var squint: Double = 0
    var score: Double = 0

    init(result: BlinkTestResult, date: Date = .now) {
        self.date = date
        duration = result.duration
        blinkCount = result.blinkCount
        partialBlinkCount = result.partialBlinkCount
        longestGap = result.longestGap
        openness = result.openness
        squint = result.squint
        score = result.score
    }

    var blinksPerMinute: Double {
        duration > 0 ? Double(blinkCount) / (duration / 60) : 0
    }

    var partialRatio: Double {
        let total = blinkCount + partialBlinkCount
        return total > 0 ? Double(partialBlinkCount) / Double(total) : 0
    }

    var advice: [String] {
        BlinkScoring.advice(rate: blinksPerMinute, partialRatio: partialRatio, longestGap: longestGap, squint: squint)
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

    /// Longest run of consecutive training days ever.
    var bestStreak: Int {
        let calendar = Calendar.current
        let days = Set(map { calendar.startOfDay(for: $0.date) }).sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for day in days {
            if let previous, let expected = calendar.date(byAdding: .day, value: 1, to: previous), expected == day {
                current += 1
            } else {
                current = 1
            }
            best = Swift.max(best, current)
            previous = day
        }
        return best
    }

    var totalReps: Int {
        reduce(0) { $0 + $1.repsCompleted }
    }
}
