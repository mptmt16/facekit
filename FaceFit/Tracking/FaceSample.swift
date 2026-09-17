import ARKit
import simd

typealias BlendShape = ARFaceAnchor.BlendShapeLocation

/// One processed frame from the TrueDepth camera (or the simulator).
struct FaceSample {
    var timestamp: TimeInterval
    var isTracked: Bool
    /// ARKit's 52 expression coefficients, 0 (neutral) ... 1 (fully active).
    var blendShapes: [BlendShape: Double]
    var head: HeadPose
    /// Eyeball centres in face-anchor space, metres.
    var leftEye: SIMD3<Float>
    var rightEye: SIMD3<Float>
    /// Face mesh vertices in face-anchor space, metres. Only filled when geometry capture is on.
    var vertices: [SIMD3<Float>]
    /// Mesh topology (constant for every ARKit face). Only filled when geometry capture is on.
    var triangleIndices: [Int16]

    static let empty = FaceSample(
        timestamp: 0, isTracked: false, blendShapes: [:], head: .zero,
        leftEye: .zero, rightEye: .zero, vertices: [], triangleIndices: []
    )

    func value(_ shape: BlendShape) -> Double {
        blendShapes[shape] ?? 0
    }

    /// Distance between the eyeball centres in millimetres.
    var eyeDistanceMM: Double {
        Double(simd_distance(leftEye, rightEye)) * 1000
    }
}

/// Head orientation relative to the phone, in degrees.
struct HeadPose: Equatable {
    /// Positive = head turned to the user's own left.
    var yaw: Double
    /// Positive = chin up.
    var pitch: Double
    /// Positive = head tilted toward the user's left shoulder.
    var roll: Double

    static let zero = HeadPose(yaw: 0, pitch: 0, roll: 0)

    static func average(_ poses: [HeadPose]) -> HeadPose {
        guard !poses.isEmpty else { return .zero }
        let n = Double(poses.count)
        return HeadPose(
            yaw: poses.map(\.yaw).reduce(0, +) / n,
            pitch: poses.map(\.pitch).reduce(0, +) / n,
            roll: poses.map(\.roll).reduce(0, +) / n
        )
    }

    /// Derives head pose from the face anchor and camera transforms (both in world space).
    ///
    /// ARKit's face frame: +x points to the face's own left, +y up, +z out of the face.
    /// Measuring where the camera sits *in that frame* avoids any dependence on
    /// sensor orientation conventions.
    static func from(face: simd_float4x4, camera: simd_float4x4) -> HeadPose {
        let xAxis = simd_normalize(SIMD3<Float>(face.columns.0.x, face.columns.0.y, face.columns.0.z))
        let yAxis = simd_normalize(SIMD3<Float>(face.columns.1.x, face.columns.1.y, face.columns.1.z))
        let zAxis = simd_normalize(SIMD3<Float>(face.columns.2.x, face.columns.2.y, face.columns.2.z))
        let facePosition = SIMD3<Float>(face.columns.3.x, face.columns.3.y, face.columns.3.z)
        let cameraPosition = SIMD3<Float>(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        let toCamera = simd_normalize(cameraPosition - facePosition)

        let cx = simd_dot(toCamera, xAxis)
        let cy = simd_dot(toCamera, yAxis)
        let cz = simd_dot(toCamera, zAxis)
        // Turning left swings the nose toward +x, so the camera appears toward -x.
        let yaw = atan2(-cx, cz)
        // Chin up swings the nose toward +y, so the camera appears toward -y.
        let pitch = atan2(-cy, cz)
        // World +y is gravity-aligned; tilting left makes "up" appear toward -x.
        let up = SIMD3<Float>(0, 1, 0)
        let roll = atan2(-simd_dot(up, xAxis), simd_dot(up, yAxis))

        let toDegrees = 180 / Double.pi
        return HeadPose(yaw: Double(yaw) * toDegrees, pitch: Double(pitch) * toDegrees, roll: Double(roll) * toDegrees)
    }
}

/// Human-readable names for all 52 ARKit blend shapes, grouped by face region.
enum BlendShapeCatalog {
    struct Entry: Identifiable {
        let shape: BlendShape
        let name: String
        var id: String { shape.rawValue }
    }

    struct Group: Identifiable {
        let title: String
        let entries: [Entry]
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "Brows", entries: [
            Entry(shape: .browInnerUp, name: "Inner brow up"),
            Entry(shape: .browOuterUpLeft, name: "Outer brow up L"),
            Entry(shape: .browOuterUpRight, name: "Outer brow up R"),
            Entry(shape: .browDownLeft, name: "Brow down L"),
            Entry(shape: .browDownRight, name: "Brow down R"),
        ]),
        Group(title: "Eyes", entries: [
            Entry(shape: .eyeBlinkLeft, name: "Blink L"),
            Entry(shape: .eyeBlinkRight, name: "Blink R"),
            Entry(shape: .eyeSquintLeft, name: "Squint L"),
            Entry(shape: .eyeSquintRight, name: "Squint R"),
            Entry(shape: .eyeWideLeft, name: "Wide L"),
            Entry(shape: .eyeWideRight, name: "Wide R"),
            Entry(shape: .eyeLookUpLeft, name: "Look up L"),
            Entry(shape: .eyeLookUpRight, name: "Look up R"),
            Entry(shape: .eyeLookDownLeft, name: "Look down L"),
            Entry(shape: .eyeLookDownRight, name: "Look down R"),
            Entry(shape: .eyeLookInLeft, name: "Look in L"),
            Entry(shape: .eyeLookInRight, name: "Look in R"),
            Entry(shape: .eyeLookOutLeft, name: "Look out L"),
            Entry(shape: .eyeLookOutRight, name: "Look out R"),
        ]),
        Group(title: "Cheeks & Nose", entries: [
            Entry(shape: .cheekPuff, name: "Cheek puff"),
            Entry(shape: .cheekSquintLeft, name: "Cheek squint L"),
            Entry(shape: .cheekSquintRight, name: "Cheek squint R"),
            Entry(shape: .noseSneerLeft, name: "Nose sneer L"),
            Entry(shape: .noseSneerRight, name: "Nose sneer R"),
        ]),
        Group(title: "Mouth", entries: [
            Entry(shape: .mouthSmileLeft, name: "Smile L"),
            Entry(shape: .mouthSmileRight, name: "Smile R"),
            Entry(shape: .mouthFrownLeft, name: "Frown L"),
            Entry(shape: .mouthFrownRight, name: "Frown R"),
            Entry(shape: .mouthDimpleLeft, name: "Dimple L"),
            Entry(shape: .mouthDimpleRight, name: "Dimple R"),
            Entry(shape: .mouthStretchLeft, name: "Stretch L"),
            Entry(shape: .mouthStretchRight, name: "Stretch R"),
            Entry(shape: .mouthPressLeft, name: "Press L"),
            Entry(shape: .mouthPressRight, name: "Press R"),
            Entry(shape: .mouthUpperUpLeft, name: "Upper lip up L"),
            Entry(shape: .mouthUpperUpRight, name: "Upper lip up R"),
            Entry(shape: .mouthLowerDownLeft, name: "Lower lip down L"),
            Entry(shape: .mouthLowerDownRight, name: "Lower lip down R"),
            Entry(shape: .mouthPucker, name: "Pucker"),
            Entry(shape: .mouthFunnel, name: "Funnel"),
            Entry(shape: .mouthLeft, name: "Mouth left"),
            Entry(shape: .mouthRight, name: "Mouth right"),
            Entry(shape: .mouthRollUpper, name: "Roll upper lip"),
            Entry(shape: .mouthRollLower, name: "Roll lower lip"),
            Entry(shape: .mouthShrugUpper, name: "Shrug upper lip"),
            Entry(shape: .mouthShrugLower, name: "Shrug lower lip"),
            Entry(shape: .mouthClose, name: "Mouth close"),
        ]),
        Group(title: "Jaw & Tongue", entries: [
            Entry(shape: .jawOpen, name: "Jaw open"),
            Entry(shape: .jawForward, name: "Jaw forward"),
            Entry(shape: .jawLeft, name: "Jaw left"),
            Entry(shape: .jawRight, name: "Jaw right"),
            Entry(shape: .tongueOut, name: "Tongue out"),
        ]),
    ]

    static let allShapes: [BlendShape] = groups.flatMap { $0.entries.map(\.shape) }
}
