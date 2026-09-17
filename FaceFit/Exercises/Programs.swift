import SwiftUI

/// A themed sequence of exercises run back to back.
struct Program: Identifiable {
    let id: String
    let name: String
    let summary: String
    let symbol: String
    let color: Color
    let exercises: [Exercise]

    var duration: TimeInterval {
        exercises.reduce(0) { $0 + $1.estimatedDuration }
    }
}

enum ProgramLibrary {
    static let all: [Program] = [
        make("jawline", "Jawline & Neck", "Work the jaw, chin and neck muscles that shape your lower face.",
             "person.crop.circle", ExerciseCategory.jaw.color,
             [("jaw-opener", 6), ("jaw-slide", 5), ("fish-face", 6), ("chin-lift", 5), ("neck-turn", 4), ("head-tilt", 3)]),
        make("smile-symmetry", "Smile Symmetry", "Build an even, controlled smile by training each side on its own.",
             "face.smiling", ExerciseCategory.cheeks.color,
             [("side-smile", 6), ("smile-lift", 6), ("kiss-smile", 6), ("cheek-puff", 4)]),
        make("bright-eyes", "Bright Eyes", "Strengthen and refresh the muscles around your eyes and brows.",
             "eye", ExerciseCategory.upperFace.color,
             [("wide-eyes", 5), ("eye-squeeze", 5), ("wink-control", 4), ("brow-raise", 6), ("nose-scrunch", 5)]),
        make("stress-release", "Stress Release", "Let go of jaw clenching, brow furrowing and screen tension.",
             "leaf", ExerciseCategory.relax.color,
             [("soft-face", 3), ("lion-stretch", 4), ("jaw-opener", 5), ("head-tilt", 3)]),
        make("full-face", "Full Face Burn", "A longer, all-round session that works every muscle group.",
             "flame", Theme.warm,
             [("smile-lift", 6), ("brow-raise", 6), ("fish-face", 6), ("lip-roll", 5), ("nose-scrunch", 6),
              ("jaw-slide", 5), ("lion-stretch", 4), ("soft-face", 2)]),
    ]

    private static func make(_ id: String, _ name: String, _ summary: String, _ symbol: String,
                             _ color: Color, _ plan: [(String, Int)]) -> Program {
        let exercises = plan.compactMap { item in
            ExerciseLibrary.exercise(id: item.0)?.with(reps: item.1)
        }
        return Program(id: id, name: name, summary: summary, symbol: symbol, color: color, exercises: exercises)
    }
}
