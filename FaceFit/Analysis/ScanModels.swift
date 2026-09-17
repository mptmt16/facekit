import Foundation
import ARKit

/// Peak movement for one guided expression during a face scan.
struct ExpressionResult: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String
    /// Peak of the left/right blend shapes, when the expression is paired.
    var left: Double?
    var right: Double?
    /// Mean peak of all measured blend shapes, 0...1.
    var peak: Double
    /// Peak a well-trained face typically reaches.
    var reference: Double
    /// 0...1 left/right balance, nil when not paired or too little movement.
    var symmetry: Double?

    var rangeScore: Double { min(1, peak / reference) }
}

/// A muscle that stayed active while the face was meant to be relaxed.
struct TensionItem: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var advice: String
    /// Mean activation at rest, 0...1.
    var level: Double
    /// Resting activation considered normal for this muscle.
    var allowance: Double

    var excess: Double { max(0, level - allowance) }
}

/// How cleanly one eye closed while the other stayed open (the Control pillar).
struct ControlResult: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    /// Closure of the eye that should close, at the cleanest moment, 0...1.
    var closed: Double
    /// Closure of the eye that should stay open, at that same moment, 0...1.
    var open: Double
    /// 0...1
    var score: Double
}

/// The averaged neutral mesh plus per-vertex asymmetry, for the 3D heat map.
struct MeshSnapshot: Codable {
    /// Flattened x, y, z in metres (face-anchor space).
    var vertices: [Float]
    var triangleIndices: [Int16]
    /// Per-vertex asymmetry in metres.
    var deviation: [Float]

    var vertexCount: Int { vertices.count / 3 }
}

/// Everything a finished scan produces, before it is saved.
struct ScanOutcome {
    var overallScore: Double
    var symmetryScore: Double
    var rangeScore: Double
    var relaxationScore: Double
    var controlScore: Double?
    var controls: [ControlResult]
    var meshAsymmetryMM: Double?
    var eyeDistanceMM: Double?
    var faceWidthMM: Double?
    var faceHeightMM: Double?
    var expressions: [ExpressionResult]
    var tension: [TensionItem]
    var mesh: MeshSnapshot?
    /// Color 3D face captured during the relaxed step, if enabled.
    var texture: FaceTexture?
    var textureJPEG: Data?
}

/// One guided step of the face scan.
struct ScanStep: Identifiable {
    enum Kind {
        case neutral
        case expression(left: BlendShape?, right: BlendShape?, others: [BlendShape], reference: Double)
        /// Close `closing` while keeping `open` open.
        case wink(closing: BlendShape, open: BlendShape)
    }

    let id: String
    let title: String
    let instruction: String
    let voice: String
    let symbol: String
    let duration: TimeInterval
    let kind: Kind

    static let standard: [ScanStep] = [
        ScanStep(id: "neutral", title: "Relaxed face",
                 instruction: "Look straight at the camera and let every muscle in your face go loose.",
                 voice: "Look straight at the camera and relax your face completely.",
                 symbol: "face.dashed", duration: 5, kind: .neutral),
        ScanStep(id: "smile", title: "Big smile",
                 instruction: "Smile as wide as you can.",
                 voice: "Now, your biggest smile.",
                 symbol: "face.smiling", duration: 3,
                 kind: .expression(left: .mouthSmileLeft, right: .mouthSmileRight, others: [], reference: 0.8)),
        ScanStep(id: "brows", title: "Raise eyebrows",
                 instruction: "Lift your eyebrows as high as they go.",
                 voice: "Raise your eyebrows as high as you can.",
                 symbol: "eyebrow", duration: 3,
                 kind: .expression(left: .browOuterUpLeft, right: .browOuterUpRight, others: [.browInnerUp], reference: 0.7)),
        ScanStep(id: "wink-left", title: "Wink left eye",
                 instruction: "Close only your left eye and keep the right one open.",
                 voice: "Wink your left eye, and keep the right one open.",
                 symbol: "eyes", duration: 3,
                 kind: .wink(closing: .eyeBlinkLeft, open: .eyeBlinkRight)),
        ScanStep(id: "wink-right", title: "Wink right eye",
                 instruction: "Close only your right eye and keep the left one open.",
                 voice: "Now wink your right eye.",
                 symbol: "eyes", duration: 3,
                 kind: .wink(closing: .eyeBlinkRight, open: .eyeBlinkLeft)),
        ScanStep(id: "eyes", title: "Close eyes tightly",
                 instruction: "Squeeze your eyes shut until you hear the next cue.",
                 voice: "Squeeze your eyes shut, tightly.",
                 symbol: "eye.slash", duration: 3,
                 kind: .expression(left: .eyeBlinkLeft, right: .eyeBlinkRight, others: [], reference: 0.9)),
        ScanStep(id: "nose", title: "Scrunch nose",
                 instruction: "Wrinkle your nose upward.",
                 voice: "Open your eyes. Now scrunch your nose.",
                 symbol: "nose", duration: 3,
                 kind: .expression(left: .noseSneerLeft, right: .noseSneerRight, others: [], reference: 0.5)),
        ScanStep(id: "cheeks", title: "Puff cheeks",
                 instruction: "Fill both cheeks with air.",
                 voice: "Puff out your cheeks.",
                 symbol: "wind", duration: 3,
                 kind: .expression(left: nil, right: nil, others: [.cheekPuff], reference: 0.5)),
        ScanStep(id: "pucker", title: "Pucker lips",
                 instruction: "Push your lips forward like a kiss.",
                 voice: "Pucker your lips.",
                 symbol: "mouth", duration: 3,
                 kind: .expression(left: nil, right: nil, others: [.mouthPucker], reference: 0.8)),
        ScanStep(id: "jaw", title: "Open wide",
                 instruction: "Open your mouth as wide as is comfortable.",
                 voice: "And open your mouth wide.",
                 symbol: "arrow.up.and.down", duration: 3,
                 kind: .expression(left: nil, right: nil, others: [.jawOpen], reference: 0.7)),
    ]

    static var totalDuration: TimeInterval {
        standard.reduce(0) { $0 + $1.duration + FaceScanEngine.leadInSeconds }
    }
}

/// Muscles checked for unconscious activity while the face is at rest.
struct TensionCheck {
    let id: String
    let name: String
    let shapes: [BlendShape]
    let allowance: Double
    let advice: String

    static let all: [TensionCheck] = [
        TensionCheck(id: "brow-furrow", name: "Brow furrow", shapes: [.browDownLeft, .browDownRight], allowance: 0.10,
                     advice: "Your brows pull together at rest. Soft Face and Brow Raise help release the frown lines area."),
        TensionCheck(id: "inner-brow", name: "Worried brow", shapes: [.browInnerUp], allowance: 0.15,
                     advice: "Your inner brows stay lifted. Practise Soft Face to let the forehead smooth out."),
        TensionCheck(id: "squint", name: "Squinting", shapes: [.eyeSquintLeft, .eyeSquintRight], allowance: 0.25,
                     advice: "Your eyes narrow at rest. Check screen brightness and distance, and try Wink Control."),
        TensionCheck(id: "lip-press", name: "Lip pressing", shapes: [.mouthPressLeft, .mouthPressRight], allowance: 0.15,
                     advice: "Your lips press together. Let them rest lightly; Kiss & Smile keeps them mobile."),
        TensionCheck(id: "frown", name: "Mouth corners down", shapes: [.mouthFrownLeft, .mouthFrownRight], allowance: 0.10,
                     advice: "Your mouth corners turn down at rest. Smile Lift strengthens the muscles that raise them."),
        TensionCheck(id: "jaw-forward", name: "Jaw pushed forward", shapes: [.jawForward], allowance: 0.10,
                     advice: "Your jaw juts forward. Let it hang loose, and try Soft Face and Jaw Opener."),
    ]
}
