import ARKit
import simd

/// Martin–Saller total (morphological) facial index classes:
/// face height (nasion–menton) ÷ face width (bizygomatic) × 100.
enum FacialIndexClass: CaseIterable {
    case hypereuryprosopic, euryprosopic, mesoprosopic, leptoprosopic, hyperleptoprosopic

    init(index: Double) {
        switch index {
        case ..<80: self = .hypereuryprosopic
        case ..<85: self = .euryprosopic
        case ..<90: self = .mesoprosopic
        case ..<95: self = .leptoprosopic
        default: self = .hyperleptoprosopic
        }
    }

    var name: String {
        switch self {
        case .hypereuryprosopic: "Hypereuryprosopic"
        case .euryprosopic: "Euryprosopic"
        case .mesoprosopic: "Mesoprosopic"
        case .leptoprosopic: "Leptoprosopic"
        case .hyperleptoprosopic: "Hyperleptoprosopic"
        }
    }

    var meaning: String {
        switch self {
        case .hypereuryprosopic: "Very broad, short face"
        case .euryprosopic: "Broad face"
        case .mesoprosopic: "Medium, balanced face"
        case .leptoprosopic: "Long, narrow face"
        case .hyperleptoprosopic: "Very long, narrow face"
        }
    }

    var range: String {
        switch self {
        case .hypereuryprosopic: "below 80"
        case .euryprosopic: "80–84.9"
        case .mesoprosopic: "85–89.9"
        case .leptoprosopic: "90–94.9"
        case .hyperleptoprosopic: "95 and above"
        }
    }

    var shortName: String {
        switch self {
        case .hypereuryprosopic: "Very broad"
        case .euryprosopic: "Broad"
        case .mesoprosopic: "Medium"
        case .leptoprosopic: "Long"
        case .hyperleptoprosopic: "Very long"
        }
    }
}

/// Upper facial index classes: upper face height (nasion–stomion) ÷ bizygomatic width × 100.
enum UpperFacialIndexClass {
    case hypereuryene, euryene, mesene, leptene, hyperleptene

    init(index: Double) {
        switch index {
        case ..<45: self = .hypereuryene
        case ..<50: self = .euryene
        case ..<55: self = .mesene
        case ..<60: self = .leptene
        default: self = .hyperleptene
        }
    }

    var name: String {
        switch self {
        case .hypereuryene: "Hypereuryene"
        case .euryene: "Euryene"
        case .mesene: "Mesene"
        case .leptene: "Leptene"
        case .hyperleptene: "Hyperleptene"
        }
    }

    var meaning: String {
        switch self {
        case .hypereuryene: "very broad upper face"
        case .euryene: "broad upper face"
        case .mesene: "medium upper face"
        case .leptene: "narrow upper face"
        case .hyperleptene: "very narrow upper face"
        }
    }
}

/// Anthropometric face type and 3D measurements from the averaged TrueDepth mesh (millimetres).
struct FaceGeometryReport {
    var facialIndex: Double
    var facialIndexClass: FacialIndexClass
    var upperFacialIndex: Double?
    var upperFacialIndexClass: UpperFacialIndexClass?
    /// The same index measured on ARKit's average face model, for context.
    var averageFacialIndex: Double?

    var faceHeight: Double
    var upperFaceHeight: Double?
    var bizygomaticWidth: Double
    var jawWidth: Double?
    var foreheadWidth: Double?
    var mouthWidth: Double?
    var eyeWidth: Double?
    var innerEyeGap: Double?
    var noseProjection: Double?
    /// Relative to ARKit's average face: +0.05 means 5% wider than average.
    var jawVsAverage: Double?
    var foreheadVsAverage: Double?
}

enum FaceShapeAnalyzer {
    private struct Measurements {
        var faceHeight: Float
        var upperFaceHeight: Float?
        var bizygomatic: Float
        var jaw: Float?
        var forehead: Float?
        var mouth: Float?
        var eyeWidth: Float?
        var innerEyeGap: Float?
        var noseProjection: Float?

        var facialIndex: Float { faceHeight / bizygomatic * 100 }
    }

    private struct Loop {
        let points: [SIMD3<Float>]
        let centroid: SIMD3<Float>
        let minX: Float
        let maxX: Float

        init(points: [SIMD3<Float>]) {
            self.points = points
            centroid = points.reduce(SIMD3<Float>.zero, +) / Float(Swift.max(points.count, 1))
            minX = points.map(\.x).min() ?? 0
            maxX = points.map(\.x).max() ?? 0
        }

        var width: Float { maxX - minX }
    }

    private static var referenceMeasured = false
    private static var reference: Measurements?

    static func report(for mesh: MeshSnapshot) -> FaceGeometryReport? {
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(mesh.vertexCount)
        for i in 0..<mesh.vertexCount {
            vertices.append(SIMD3<Float>(mesh.vertices[i * 3], mesh.vertices[i * 3 + 1], mesh.vertices[i * 3 + 2]))
        }
        guard let user = measure(vertices: vertices, indices: mesh.triangleIndices) else { return nil }
        let average = averageFace()

        func relative(_ value: Float?, _ averageValue: Float?) -> Double? {
            guard let value, let averageValue, let average, averageValue > 0 else { return nil }
            return Double((value / user.bizygomatic) / (averageValue / average.bizygomatic) - 1)
        }

        let facialIndex = Double(user.facialIndex)
        let upperIndex = user.upperFaceHeight.map { Double($0 / user.bizygomatic * 100) }
        return FaceGeometryReport(
            facialIndex: facialIndex,
            facialIndexClass: FacialIndexClass(index: facialIndex),
            upperFacialIndex: upperIndex,
            upperFacialIndexClass: upperIndex.map { UpperFacialIndexClass(index: $0) },
            averageFacialIndex: average.map { Double($0.facialIndex) },
            faceHeight: mm(user.faceHeight),
            upperFaceHeight: user.upperFaceHeight.map(mm),
            bizygomaticWidth: mm(user.bizygomatic),
            jawWidth: user.jaw.map(mm),
            foreheadWidth: user.forehead.map(mm),
            mouthWidth: user.mouth.map(mm),
            eyeWidth: user.eyeWidth.map(mm),
            innerEyeGap: user.innerEyeGap.map(mm),
            noseProjection: user.noseProjection.map(mm),
            jawVsAverage: relative(user.jaw, average?.jaw),
            foreheadVsAverage: relative(user.forehead, average?.forehead)
        )
    }

    private static func mm(_ metres: Float) -> Double { Double(metres) * 1000 }

    /// ARKit's generic neutral face, measured once, as the "average" reference.
    private static func averageFace() -> Measurements? {
        if !referenceMeasured {
            referenceMeasured = true
            if let geometry = ARFaceGeometry(blendShapes: [:]) {
                reference = measure(vertices: geometry.vertices, indices: geometry.triangleIndices)
            }
        }
        return reference
    }

    // MARK: - Landmarks and measurements

    private static func measure(vertices: [SIMD3<Float>], indices: [Int16]) -> Measurements? {
        guard vertices.count > 100, indices.count >= 3 else { return nil }
        let loops = MeshTopology.boundaryLoops(indices: indices, vertexCount: vertices.count)
            .map { Loop(points: $0.map { vertices[$0] }) }

        // The face outline is the widest open boundary; the eye and mouth openings are the others.
        guard let outlineIndex = loops.indices.max(by: { loops[$0].width < loops[$1].width }) else { return nil }
        let outline = loops[outlineIndex]
        let holes = loops.indices.filter { $0 != outlineIndex }.map { loops[$0] }

        // Pronasale: the most forward point near the midline.
        guard let noseTip = vertices.filter({ abs($0.x) < 0.015 }).max(by: { $0.z < $1.z }) else { return nil }

        let eyes = holes
            .filter { $0.centroid.y > noseTip.y + 0.01 }
            .sorted { $0.points.count > $1.points.count }
            .prefix(2)
        let mouth = holes
            .filter { $0.centroid.y < noseTip.y - 0.005 && abs($0.centroid.x) < 0.015 }
            .max { $0.points.count < $1.points.count }
        let eyeY = eyes.isEmpty ? noseTip.y + 0.035 : eyes.map(\.centroid.y).reduce(0, +) / Float(eyes.count)

        let midline = vertices.filter { abs($0.x) < 0.004 }
        // Soft-tissue nasion: the deepest point of the midline profile between the brows and the nose bridge.
        guard let nasion = midline.filter({ $0.y > eyeY - 0.005 && $0.y < eyeY + 0.02 }).min(by: { $0.z < $1.z }),
              // Soft-tissue menton: the lowest point of the chin on the midline.
              let menton = midline.min(by: { $0.y < $1.y }) else { return nil }

        func width(at y: Float) -> Float? {
            for tolerance: Float in [0.004, 0.008] {
                let band = outline.points.filter { abs($0.y - y) < tolerance }
                if let left = band.filter({ $0.x > 0 }).map(\.x).max(),
                   let right = band.filter({ $0.x < 0 }).map(\.x).min() {
                    return left - right
                }
            }
            return nil
        }

        // Bizygomatic width: the widest point of the face between nose-tip and eye level.
        var bizygomatic: Float = 0
        var y = noseTip.y
        while y <= eyeY {
            if let w = width(at: y) { bizygomatic = Swift.max(bizygomatic, w) }
            y += 0.002
        }
        let faceHeight = simd_distance(nasion, menton)
        guard bizygomatic > 0.05, faceHeight > 0.05 else { return nil }

        var result = Measurements(faceHeight: faceHeight, bizygomatic: bizygomatic)
        let topY = outline.points.filter { abs($0.x) < 0.02 }.map(\.y).max() ?? eyeY + 0.05
        result.forehead = width(at: eyeY + 0.55 * (topY - eyeY))

        if let mouth {
            // Stomion: where the lips meet, the centre of the mouth opening.
            result.upperFaceHeight = simd_distance(nasion, mouth.centroid)
            result.mouth = mouth.width
            result.jaw = width(at: mouth.centroid.y - 0.35 * (mouth.centroid.y - menton.y))
        }

        if !eyes.isEmpty {
            result.eyeWidth = eyes.map(\.width).reduce(0, +) / Float(eyes.count)
            let eyePoints = eyes.flatMap(\.points)
            result.noseProjection = noseTip.z - eyePoints.map(\.z).reduce(0, +) / Float(eyePoints.count)
        }
        if eyes.count == 2,
           let leftEye = eyes.max(by: { $0.centroid.x < $1.centroid.x }),
           let rightEye = eyes.min(by: { $0.centroid.x < $1.centroid.x }) {
            result.innerEyeGap = leftEye.minX - rightEye.maxX
        }
        return result
    }
}
