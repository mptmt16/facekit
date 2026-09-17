import SwiftUI

/// The four measurable pillars that make up the Face Score.
enum FacePillar: String, CaseIterable, Identifiable {
    case symmetry, mobility, control, relaxation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .symmetry: "Symmetry"
        case .mobility: "Mobility"
        case .control: "Control"
        case .relaxation: "Relaxation"
        }
    }

    var symbol: String {
        switch self {
        case .symmetry: "circle.lefthalf.filled"
        case .mobility: "arrow.up.left.and.arrow.down.right"
        case .control: "scope"
        case .relaxation: "leaf"
        }
    }

    /// Share of the overall Face Score.
    var weight: Double {
        switch self {
        case .symmetry: 0.30
        case .mobility: 0.25
        case .control: 0.20
        case .relaxation: 0.25
        }
    }

    var explanation: String {
        switch self {
        case .symmetry: "How evenly both sides of your face are shaped and move."
        case .mobility: "How far your muscles move in big expressions."
        case .control: "How well you move one side on its own, like a clean wink."
        case .relaxation: "How free your resting face is from hidden tension."
        }
    }

    var color: Color {
        switch self {
        case .symmetry: Theme.accent
        case .mobility: Theme.secondary
        case .control: Color(red: 1.00, green: 0.45, blue: 0.60)
        case .relaxation: Color(red: 0.55, green: 0.85, blue: 0.45)
        }
    }
}

/// Pillar scores (0–100) for one scan and the weighted Face Score they produce.
struct FaceScoreBreakdown: Equatable {
    var symmetry: Double
    var mobility: Double
    /// Nil for scans recorded before the control test existed.
    var control: Double?
    var relaxation: Double

    func value(for pillar: FacePillar) -> Double? {
        switch pillar {
        case .symmetry: return symmetry
        case .mobility: return mobility
        case .control: return control
        case .relaxation: return relaxation
        }
    }

    /// Weighted mean of the pillars that were measured.
    var overall: Double {
        var total = 0.0
        var weights = 0.0
        for pillar in FacePillar.allCases {
            guard let score = self.value(for: pillar) else { continue }
            total += score * pillar.weight
            weights += pillar.weight
        }
        return weights > 0 ? total / weights : 0
    }

    var weakest: FacePillar? {
        measured.min { $0.score < $1.score }?.pillar
    }

    var strongest: FacePillar? {
        measured.max { $0.score < $1.score }?.pillar
    }

    private var measured: [(pillar: FacePillar, score: Double)] {
        FacePillar.allCases.compactMap { pillar in
            value(for: pillar).map { (pillar: pillar, score: $0) }
        }
    }
}

/// Named tiers so progress feels tangible.
enum FaceLevel: Int, CaseIterable {
    case starting, developing, fit, strong, elite

    init(score: Double) {
        self = FaceLevel.allCases.last { score >= $0.minimumScore } ?? .starting
    }

    var minimumScore: Double {
        switch self {
        case .starting: 0
        case .developing: 40
        case .fit: 60
        case .strong: 75
        case .elite: 90
        }
    }

    var title: String {
        switch self {
        case .starting: "Getting started"
        case .developing: "Developing"
        case .fit: "Fit"
        case .strong: "Strong"
        case .elite: "Elite"
        }
    }

    var symbol: String {
        switch self {
        case .starting: "leaf.fill"
        case .developing: "figure.walk"
        case .fit: "figure.run"
        case .strong: "bolt.fill"
        case .elite: "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .starting: Color(red: 0.70, green: 0.70, blue: 0.75)
        case .developing: Color(red: 1.00, green: 0.78, blue: 0.35)
        case .fit: Theme.accent
        case .strong: Theme.secondary
        case .elite: Theme.warm
        }
    }

    var next: FaceLevel? { FaceLevel(rawValue: rawValue + 1) }
}
