import SwiftUI

/// Areas of the face the analyzer scores and the plan can target.
enum FaceRegion: String, CaseIterable, Identifiable {
    case jawline, cheeks, lips, eyes, forehead, symmetry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jawline: "Jawline"
        case .cheeks: "Cheeks"
        case .lips: "Lips & Mouth"
        case .eyes: "Eye Area"
        case .forehead: "Forehead & Brows"
        case .symmetry: "Symmetry"
        }
    }

    var goalTitle: String {
        switch self {
        case .jawline: "Define my jawline"
        case .cheeks: "Lift my cheeks"
        case .lips: "Tone my lips and mouth"
        case .eyes: "Refresh my eye area"
        case .forehead: "Relax my forehead"
        case .symmetry: "Balance both sides"
        }
    }

    var goalDetail: String {
        switch self {
        case .jawline: "Jaw range, chin and neck muscles"
        case .cheeks: "Smile lift and cheek strength"
        case .lips: "Lip strength and relaxed mouth corners"
        case .eyes: "Eyelid strength, control and less squinting"
        case .forehead: "Brow lift and releasing frown tension"
        case .symmetry: "Even movement on the left and right"
        }
    }

    var symbol: String {
        switch self {
        case .jawline: "chevron.compact.down"
        case .cheeks: "face.smiling"
        case .lips: "mouth"
        case .eyes: "eye"
        case .forehead: "eyebrow"
        case .symmetry: "circle.lefthalf.filled"
        }
    }

    var color: Color {
        switch self {
        case .jawline: ExerciseCategory.jaw.color
        case .cheeks: ExerciseCategory.cheeks.color
        case .lips: ExerciseCategory.mouth.color
        case .eyes: ExerciseCategory.upperFace.color
        case .forehead: Color(red: 0.95, green: 0.80, blue: 0.40)
        case .symmetry: Theme.secondary
        }
    }

    /// Exercises that train this area, best first.
    var exerciseIDs: [String] {
        switch self {
        case .jawline: ["jaw-opener", "chin-lift", "jaw-slide", "fish-face"]
        case .cheeks: ["smile-lift", "cheek-puff", "side-smile", "kiss-smile"]
        case .lips: ["fish-face", "kiss-smile", "lip-roll"]
        case .eyes: ["eye-squeeze", "wink-control", "wide-eyes"]
        case .forehead: ["brow-raise", "soft-face", "nose-scrunch"]
        case .symmetry: ["side-smile", "wink-control", "smile-lift"]
        }
    }
}

/// One area's score (0–100) with a plain-language insight.
struct RegionScore: Identifiable {
    let region: FaceRegion
    /// Nil when the scan didn't measure this area.
    let score: Double?
    let insight: String

    var id: String { region.rawValue }
}

/// Turns a saved scan into per-area scores.
enum RegionScorer {
    private struct Part {
        let name: String
        let value: Double?
        let weight: Double
    }

    static func scores(for scan: FaceScan) -> [RegionScore] {
        var expressions: [String: ExpressionResult] = [:]
        for expression in scan.expressions { expressions[expression.id] = expression }
        var tension: [String: TensionItem] = [:]
        for item in scan.tension { tension[item.id] = item }
        let controls = scan.controls

        func range(_ id: String) -> Double? { expressions[id]?.rangeScore }
        func balance(_ id: String) -> Double? { expressions[id]?.symmetry }
        func relaxed(_ id: String) -> Double? {
            tension[id].map { 1 - Swift.min(1, $0.excess / 0.25) }
        }

        let control: Double? = controls.isEmpty
            ? nil
            : controls.map(\.score).reduce(0, +) / Double(controls.count)
        let symmetries = scan.expressions.compactMap(\.symmetry)
        let movementBalance: Double? = symmetries.isEmpty
            ? nil
            : symmetries.reduce(0, +) / Double(symmetries.count)
        let structuralBalance = scan.meshAsymmetryMM.map { Swift.min(1, Swift.max(0, 1 - ($0 - 1) * 0.15)) }

        return FaceRegion.allCases.map { region -> RegionScore in
            let parts: [Part]
            switch region {
            case .jawline:
                parts = [Part(name: "Jaw opening range", value: range("jaw"), weight: 0.6),
                         Part(name: "Relaxed jaw position", value: relaxed("jaw-forward"), weight: 0.4)]
            case .cheeks:
                parts = [Part(name: "Smile lift", value: range("smile"), weight: 0.4),
                         Part(name: "Smile balance", value: balance("smile"), weight: 0.3),
                         Part(name: "Cheek strength", value: range("cheeks"), weight: 0.3)]
            case .lips:
                parts = [Part(name: "Pucker strength", value: range("pucker"), weight: 0.5),
                         Part(name: "Relaxed lips", value: relaxed("lip-press"), weight: 0.25),
                         Part(name: "Lifted mouth corners", value: relaxed("frown"), weight: 0.25)]
            case .eyes:
                parts = [Part(name: "Eye closing strength", value: range("eyes"), weight: 0.3),
                         Part(name: "Wink control", value: control, weight: 0.4),
                         Part(name: "Relaxed eyes", value: relaxed("squint"), weight: 0.3)]
            case .forehead:
                parts = [Part(name: "Brow lift", value: range("brows"), weight: 0.4),
                         Part(name: "Brow balance", value: balance("brows"), weight: 0.2),
                         Part(name: "Smooth brow", value: relaxed("brow-furrow"), weight: 0.25),
                         Part(name: "Relaxed inner brow", value: relaxed("inner-brow"), weight: 0.15)]
            case .symmetry:
                parts = [Part(name: "Movement balance", value: movementBalance, weight: 0.6),
                         Part(name: "Structural balance", value: structuralBalance, weight: 0.4)]
            }
            return score(region: region, parts: parts)
        }
    }

    private static func score(region: FaceRegion, parts: [Part]) -> RegionScore {
        let measured = parts.compactMap { part in part.value.map { (part: part, value: $0) } }
        let totalWeight = measured.reduce(0) { $0 + $1.part.weight }
        guard totalWeight > 0 else {
            return RegionScore(region: region, score: nil, insight: "Not measured in this scan.")
        }
        let score = 100 * measured.reduce(0) { $0 + $1.value * $1.part.weight } / totalWeight
        let weakest = measured.min { $0.value < $1.value }

        let insight: String
        if score >= 85 {
            insight = "Strong. Keep it up with regular practice."
        } else if let weakest {
            insight = "\(weakest.part.name) has the most room to improve (\(Int((weakest.value * 100).rounded()))%)."
        } else {
            insight = ""
        }
        return RegionScore(region: region, score: score, insight: insight)
    }
}

/// Stores the user's improvement goals in AppStorage as a comma-separated string.
enum GoalStore {
    static func decode(_ raw: String) -> Set<FaceRegion> {
        Set(raw.split(separator: ",").compactMap { FaceRegion(rawValue: String($0)) })
    }

    static func encode(_ goals: Set<FaceRegion>) -> String {
        goals.map(\.rawValue).sorted().joined(separator: ",")
    }
}
