import SwiftUI
import ARKit

enum ExerciseCategory: String, CaseIterable, Identifiable {
    case cheeks, mouth, jaw, upperFace, neck, relax

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cheeks: "Cheeks & Smile"
        case .mouth: "Lips & Mouth"
        case .jaw: "Jaw & Tongue"
        case .upperFace: "Brows, Eyes & Nose"
        case .neck: "Neck"
        case .relax: "Relaxation"
        }
    }

    var symbol: String {
        switch self {
        case .cheeks: "face.smiling"
        case .mouth: "mouth"
        case .jaw: "arrow.left.and.right"
        case .upperFace: "eyebrow"
        case .neck: "figure.cooldown"
        case .relax: "leaf"
        }
    }

    var color: Color {
        switch self {
        case .cheeks: Color(red: 1.00, green: 0.62, blue: 0.40)
        case .mouth: Color(red: 1.00, green: 0.45, blue: 0.60)
        case .jaw: Color(red: 0.55, green: 0.55, blue: 1.00)
        case .upperFace: Color(red: 0.30, green: 0.85, blue: 0.78)
        case .neck: Color(red: 0.45, green: 0.75, blue: 1.00)
        case .relax: Color(red: 0.55, green: 0.85, blue: 0.45)
        }
    }
}

/// A measurable quantity read from a face sample.
enum FaceSignal: Hashable {
    /// One blend shape coefficient.
    case shape(BlendShape)
    /// A left/right blend shape pair; the value is their mean and symmetry is measurable.
    case pair(BlendShape, BlendShape)
    /// Head angles in degrees, relative to the pose captured during the countdown.
    case yaw, pitch, roll

    var isHead: Bool {
        switch self {
        case .yaw, .pitch, .roll: true
        default: false
        }
    }

    /// Human-readable name for the muscle readouts during a session.
    var displayName: String {
        switch self {
        case .shape(let shape):
            return BlendShapeCatalog.name(for: shape)
        case .pair(let left, _):
            let name = BlendShapeCatalog.name(for: left)
            return name.hasSuffix(" L") ? String(name.dropLast(2)) : name
        case .yaw:
            return "Head turn"
        case .pitch:
            return "Chin lift"
        case .roll:
            return "Head tilt"
        }
    }

    func value(in sample: FaceSample, baseline: HeadPose) -> Double {
        switch self {
        case .shape(let shape): sample.value(shape)
        case .pair(let left, let right): (sample.value(left) + sample.value(right)) / 2
        case .yaw: sample.head.yaw - baseline.yaw
        case .pitch: sample.head.pitch - baseline.pitch
        case .roll: sample.head.roll - baseline.roll
        }
    }

    /// 0...1 balance between left and right, or nil when there is too little movement to judge.
    func symmetry(in sample: FaceSample) -> Double? {
        guard case .pair(let left, let right) = self else { return nil }
        return Symmetry.score(left: sample.value(left), right: sample.value(right))
    }
}

enum Symmetry {
    static func score(left: Double, right: Double, minimumMovement: Double = 0.08) -> Double? {
        let strongest = max(left, right)
        guard strongest >= minimumMovement else { return nil }
        return 1 - abs(left - right) / strongest
    }
}

/// A condition a pose must satisfy, e.g. "smile at least 0.55" or "brow furrow at most 0.12".
struct Requirement: Hashable {
    enum Mode: Hashable { case above, below }

    var signal: FaceSignal
    var target: Double
    var mode: Mode

    static func atLeast(_ signal: FaceSignal, _ target: Double) -> Requirement {
        Requirement(signal: signal, target: target, mode: .above)
    }

    static func atMost(_ signal: FaceSignal, _ target: Double) -> Requirement {
        Requirement(signal: signal, target: target, mode: .below)
    }

    /// 1.0 means the requirement is exactly met. `difficulty` > 1 makes targets harder.
    func progress(in sample: FaceSample, baseline: HeadPose, difficulty: Double) -> Double {
        let value = signal.value(in: sample, baseline: baseline)
        switch mode {
        case .above:
            let goal = target * difficulty
            guard goal != 0 else { return 1 }
            return min(1.5, max(0, value / goal))
        case .below:
            let ceiling = target / difficulty
            return min(1, max(0, 1 - (value - ceiling) / max(ceiling, 0.1)))
        }
    }
}

/// One held position within a repetition.
struct Pose: Hashable {
    var cue: String
    var requirements: [Requirement]

    func progress(in sample: FaceSample, baseline: HeadPose, difficulty: Double) -> Double {
        requirements
            .map { $0.progress(in: sample, baseline: baseline, difficulty: difficulty) }
            .min() ?? 0
    }

    func symmetry(in sample: FaceSample) -> Double? {
        let scores = requirements.compactMap { $0.signal.symmetry(in: sample) }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var isRelaxation: Bool {
        requirements.allSatisfy { $0.mode == .below }
    }
}

enum ExerciseLevel: String, CaseIterable, Hashable {
    case beginner, intermediate, advanced

    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .beginner: Color(red: 0.35, green: 0.85, blue: 0.55)
        case .intermediate: Theme.secondary
        case .advanced: Color(red: 1.00, green: 0.45, blue: 0.45)
        }
    }

    var bars: Int {
        switch self {
        case .beginner: 1
        case .intermediate: 2
        case .advanced: 3
        }
    }
}

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let symbol: String
    let summary: String
    let muscles: String
    let steps: [String]
    let poses: [Pose]
    var holdSeconds: Double
    var reps: Int
    var restSeconds: Double = 2
    var level: ExerciseLevel = .beginner

    var usesHeadPose: Bool {
        poses.contains { $0.requirements.contains { $0.signal.isHead } }
    }

    /// Whether the user must visibly relax before the next rep counts.
    var requiresRelaxBetweenReps: Bool {
        !(poses.first?.isRelaxation ?? false)
    }

    var estimatedDuration: TimeInterval {
        Double(reps) * (Double(poses.count) * (holdSeconds + 1.5) + restSeconds) + 4
    }

    func with(reps: Int? = nil, holdSeconds: Double? = nil) -> Exercise {
        var copy = self
        if let reps { copy.reps = reps }
        if let holdSeconds { copy.holdSeconds = holdSeconds }
        return copy
    }
}

extension TimeInterval {
    /// "1:05" style.
    var clockString: String {
        let total = Int(self.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
