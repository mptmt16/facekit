import ARKit
import Foundation

enum ExerciseLibrary {
    static let all: [Exercise] = [
        // MARK: Cheeks & Smile
        Exercise(
            id: "smile-lift", name: "Smile Lift", category: .cheeks, symbol: "face.smiling",
            summary: "A wide, closed-lip smile that lifts the cheeks toward the eyes.",
            muscles: "Zygomaticus major & minor, risorius",
            steps: ["Keep your lips together.", "Smile as wide as you can, lifting your cheeks.", "Hold, then relax slowly."],
            poses: [Pose(cue: "Big smile", requirements: [.atLeast(.pair(.mouthSmileLeft, .mouthSmileRight), 0.55)])],
            holdSeconds: 3, reps: 8
        ),
        Exercise(
            id: "side-smile", name: "Side Smile", category: .cheeks, symbol: "face.smiling.inverse",
            summary: "Smile with one side at a time to build control and balance.",
            muscles: "Zygomaticus major, one side at a time",
            steps: ["Lift only the left corner of your mouth.", "Relax, then lift only the right corner.", "Try to keep the other side still."],
            poses: [
                Pose(cue: "Smile on your left side", requirements: [.atLeast(.shape(.mouthSmileLeft), 0.45)]),
                Pose(cue: "Smile on your right side", requirements: [.atLeast(.shape(.mouthSmileRight), 0.45)]),
            ],
            holdSeconds: 2, reps: 6
        ),
        Exercise(
            id: "cheek-puff", name: "Cheek Puff", category: .cheeks, symbol: "wind",
            summary: "Fill your cheeks with air to stretch and tone the cheek wall.",
            muscles: "Buccinator, orbicularis oris",
            steps: ["Close your lips firmly.", "Puff both cheeks full of air.", "Hold without letting air escape."],
            poses: [Pose(cue: "Puff your cheeks", requirements: [.atLeast(.shape(.cheekPuff), 0.35)])],
            holdSeconds: 5, reps: 6
        ),

        // MARK: Lips & Mouth
        Exercise(
            id: "fish-face", name: "Fish Face", category: .mouth, symbol: "fish",
            summary: "Suck in your cheeks and pucker to work the lips and hollows of the cheeks.",
            muscles: "Orbicularis oris, buccinator",
            steps: ["Push your lips forward into a pucker.", "Draw your cheeks inward.", "Hold the shape."],
            poses: [Pose(cue: "Pucker your lips", requirements: [.atLeast(.shape(.mouthPucker), 0.55)])],
            holdSeconds: 4, reps: 8
        ),
        Exercise(
            id: "kiss-smile", name: "Kiss & Smile", category: .mouth, symbol: "mouth",
            summary: "Alternate between a pucker and a wide smile for full lip mobility.",
            muscles: "Orbicularis oris, zygomaticus, risorius",
            steps: ["Pucker as if blowing a kiss.", "Switch to the widest smile you can.", "Keep alternating smoothly."],
            poses: [
                Pose(cue: "Kiss", requirements: [.atLeast(.shape(.mouthPucker), 0.5)]),
                Pose(cue: "Smile", requirements: [.atLeast(.pair(.mouthSmileLeft, .mouthSmileRight), 0.5)]),
            ],
            holdSeconds: 1.5, reps: 8, restSeconds: 1
        ),
        Exercise(
            id: "lip-roll", name: "Lip Roll", category: .mouth, symbol: "mouth.fill",
            summary: "Roll both lips inward over your teeth to strengthen the lip ring.",
            muscles: "Orbicularis oris",
            steps: ["Roll your upper and lower lips in.", "Press them gently together.", "Hold, then release."],
            poses: [Pose(cue: "Roll your lips in", requirements: [
                .atLeast(.shape(.mouthRollLower), 0.35),
                .atLeast(.shape(.mouthRollUpper), 0.3),
            ])],
            holdSeconds: 3, reps: 6
        ),

        // MARK: Jaw & Tongue
        Exercise(
            id: "jaw-opener", name: "Jaw Opener", category: .jaw, symbol: "arrow.up.and.down",
            summary: "Open your mouth wide in a slow, controlled stretch.",
            muscles: "Digastric, platysma, masseter (stretch)",
            steps: ["Keep your tongue relaxed.", "Open your mouth as wide as is comfortable.", "Hold, then close slowly."],
            poses: [Pose(cue: "Open wide", requirements: [.atLeast(.shape(.jawOpen), 0.55)])],
            holdSeconds: 3, reps: 8
        ),
        Exercise(
            id: "jaw-slide", name: "Jaw Slide", category: .jaw, symbol: "arrow.left.and.right",
            summary: "Glide the lower jaw side to side to loosen the jaw joint.",
            muscles: "Lateral pterygoids",
            steps: ["Part your lips slightly.", "Slide your lower jaw to the left.", "Then slide it to the right."],
            poses: [
                Pose(cue: "Jaw to the left", requirements: [.atLeast(.shape(.jawLeft), 0.25)]),
                Pose(cue: "Jaw to the right", requirements: [.atLeast(.shape(.jawRight), 0.25)]),
            ],
            holdSeconds: 2, reps: 6
        ),
        Exercise(
            id: "lion-stretch", name: "Lion Stretch", category: .jaw, symbol: "flame",
            summary: "The classic yoga lion: mouth wide, tongue out, eyes wide open.",
            muscles: "Whole face, tongue, platysma",
            steps: ["Open your mouth wide.", "Stick your tongue out and down.", "Open your eyes wide and hold."],
            poses: [Pose(cue: "Mouth open, tongue out, eyes wide", requirements: [
                .atLeast(.shape(.jawOpen), 0.45),
                .atLeast(.shape(.tongueOut), 0.25),
                .atLeast(.pair(.eyeWideLeft, .eyeWideRight), 0.2),
            ])],
            holdSeconds: 3, reps: 5, restSeconds: 3
        ),

        // MARK: Brows, Eyes & Nose
        Exercise(
            id: "brow-raise", name: "Brow Raise", category: .upperFace, symbol: "eyebrow",
            summary: "Lift both eyebrows high to work the forehead.",
            muscles: "Frontalis",
            steps: ["Look straight ahead.", "Raise your eyebrows as high as possible.", "Hold, then lower slowly."],
            poses: [Pose(cue: "Raise your eyebrows", requirements: [
                .atLeast(.pair(.browOuterUpLeft, .browOuterUpRight), 0.45),
                .atLeast(.shape(.browInnerUp), 0.4),
            ])],
            holdSeconds: 3, reps: 8
        ),
        Exercise(
            id: "eye-squeeze", name: "Eye Squeeze", category: .upperFace, symbol: "eye.slash",
            summary: "Close your eyes tightly to strengthen the muscles around the eyes.",
            muscles: "Orbicularis oculi",
            steps: ["Squeeze both eyes shut.", "Listen for the voice cue to relax.", "Open gently."],
            poses: [Pose(cue: "Squeeze your eyes shut", requirements: [.atLeast(.pair(.eyeBlinkLeft, .eyeBlinkRight), 0.8)])],
            holdSeconds: 3, reps: 6
        ),
        Exercise(
            id: "wide-eyes", name: "Wide Eyes", category: .upperFace, symbol: "eye",
            summary: "Open your eyes as wide as you can without raising your brows too much.",
            muscles: "Levator palpebrae, frontalis",
            steps: ["Look straight ahead.", "Widen your eyes as far as possible.", "Hold without blinking."],
            poses: [Pose(cue: "Eyes wide open", requirements: [.atLeast(.pair(.eyeWideLeft, .eyeWideRight), 0.35)])],
            holdSeconds: 3, reps: 6
        ),
        Exercise(
            id: "wink-control", name: "Wink Control", category: .upperFace, symbol: "eyes",
            summary: "Close one eye at a time while keeping the other open.",
            muscles: "Orbicularis oculi, one side at a time",
            steps: ["Close your left eye; keep the right open.", "Switch to the right eye.", "Keep the rest of your face still."],
            poses: [
                Pose(cue: "Close your left eye", requirements: [
                    .atLeast(.shape(.eyeBlinkLeft), 0.7),
                    .atMost(.shape(.eyeBlinkRight), 0.35),
                ]),
                Pose(cue: "Close your right eye", requirements: [
                    .atLeast(.shape(.eyeBlinkRight), 0.7),
                    .atMost(.shape(.eyeBlinkLeft), 0.35),
                ]),
            ],
            holdSeconds: 2, reps: 5
        ),
        Exercise(
            id: "nose-scrunch", name: "Nose Scrunch", category: .upperFace, symbol: "nose",
            summary: "Wrinkle your nose upward like you smelled something bad.",
            muscles: "Nasalis, levator labii superioris",
            steps: ["Pull your nose upward.", "Let your upper lip lift slightly.", "Hold, then release."],
            poses: [Pose(cue: "Scrunch your nose", requirements: [.atLeast(.pair(.noseSneerLeft, .noseSneerRight), 0.3)])],
            holdSeconds: 2, reps: 8
        ),

        // MARK: Neck
        Exercise(
            id: "neck-turn", name: "Neck Turn", category: .neck, symbol: "arrow.left.arrow.right",
            summary: "Slow head turns to loosen the neck. Keep your phone still at eye level.",
            muscles: "Sternocleidomastoid, upper trapezius",
            steps: ["Hold your phone at eye level.", "Turn your head to the left.", "Return and turn to the right."],
            poses: [
                Pose(cue: "Turn your head left", requirements: [.atLeast(.yaw, 25)]),
                Pose(cue: "Turn your head right", requirements: [.atLeast(.yaw, -25)]),
            ],
            holdSeconds: 2, reps: 5
        ),
        Exercise(
            id: "chin-lift", name: "Chin Lift", category: .neck, symbol: "arrow.up.circle",
            summary: "Tilt your head back to stretch the front of the neck and jawline.",
            muscles: "Platysma, suprahyoids",
            steps: ["Sit up tall.", "Tilt your chin toward the ceiling.", "Hold the stretch, then return."],
            poses: [Pose(cue: "Chin up", requirements: [.atLeast(.pitch, 20)])],
            holdSeconds: 3, reps: 5
        ),
        Exercise(
            id: "head-tilt", name: "Head Tilt", category: .neck, symbol: "arrow.triangle.2.circlepath",
            summary: "Tilt your ear toward each shoulder to stretch the sides of the neck.",
            muscles: "Scalenes, upper trapezius",
            steps: ["Keep your shoulders down.", "Tilt your left ear toward your left shoulder.", "Then tilt to the right."],
            poses: [
                Pose(cue: "Tilt to your left shoulder", requirements: [.atLeast(.roll, 20)]),
                Pose(cue: "Tilt to your right shoulder", requirements: [.atLeast(.roll, -20)]),
            ],
            holdSeconds: 3, reps: 4
        ),

        // MARK: Relaxation
        Exercise(
            id: "soft-face", name: "Soft Face", category: .relax, symbol: "leaf",
            summary: "Release every tension point: smooth brow, soft eyes, loose lips and jaw.",
            muscles: "Corrugator, orbicularis oculi & oris, masseter (release)",
            steps: ["Breathe out slowly.", "Let your brow smooth and your eyes soften.", "Unclench your jaw and let your lips rest."],
            poses: [Pose(cue: "Soften your whole face", requirements: [
                .atMost(.pair(.browDownLeft, .browDownRight), 0.12),
                .atMost(.pair(.eyeSquintLeft, .eyeSquintRight), 0.3),
                .atMost(.pair(.mouthPressLeft, .mouthPressRight), 0.18),
                .atMost(.shape(.jawForward), 0.15),
            ])],
            holdSeconds: 8, reps: 3, restSeconds: 3
        ),
    ]

    static func exercise(id: String) -> Exercise? {
        all.first { $0.id == id }
    }

    static func exercises(in category: ExerciseCategory) -> [Exercise] {
        all.filter { $0.category == category }
    }

    /// A balanced ~5 minute session covering every region.
    static let dailyRoutine: [Exercise] = {
        let plan: [(id: String, reps: Int)] = [
            ("smile-lift", 5), ("brow-raise", 5), ("kiss-smile", 5),
            ("cheek-puff", 4), ("jaw-slide", 4), ("neck-turn", 3), ("soft-face", 2),
        ]
        return plan.compactMap { item in
            ExerciseLibrary.exercise(id: item.id)?.with(reps: item.reps)
        }
    }()

    static var dailyRoutineDuration: TimeInterval {
        dailyRoutine.reduce(0) { $0 + $1.estimatedDuration }
    }

    /// Exercises that target a face-scan expression or tension finding.
    static func recommended(forFinding id: String) -> [Exercise] {
        let ids: [String] = switch id {
        case "smile", "frown": ["side-smile", "smile-lift"]
        case "brows": ["brow-raise", "wide-eyes"]
        case "eyes", "squint": ["eye-squeeze", "wink-control"]
        case "nose": ["nose-scrunch"]
        case "cheeks": ["cheek-puff", "fish-face"]
        case "pucker", "lip-press": ["kiss-smile", "fish-face"]
        case "jaw": ["jaw-opener", "jaw-slide"]
        case "brow-furrow", "inner-brow", "jaw-forward": ["soft-face", "brow-raise"]
        default: ["soft-face"]
        }
        return ids.compactMap(exercise(id:))
    }
}
