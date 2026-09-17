import ARKit
import simd

enum FaceShape: String {
    case oval, round, square, heart, diamond, oblong

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .oval: "oval.portrait"
        case .round: "circle"
        case .square: "square"
        case .heart: "heart"
        case .diamond: "diamond"
        case .oblong: "capsule.portrait"
        }
    }

    var description: String {
        switch self {
        case .oval: "Balanced proportions with a gently tapered jaw, a little longer than wide."
        case .round: "Width and length are close, with fuller cheeks and a softer jawline."
        case .square: "A strong, wide jaw close to the width of your cheekbones."
        case .heart: "A wider forehead that tapers to a narrower jaw and chin."
        case .diamond: "Cheekbones are the widest point, with a narrower forehead and jaw."
        case .oblong: "Noticeably longer than wide, with similar widths from top to bottom."
        }
    }
}

/// Face shape and proportions measured from the averaged 3D mesh, in millimetres.
struct FaceGeometryReport {
    var shape: FaceShape
    var faceLength: Double
    var cheekWidth: Double
    var jawWidth: Double?
    var foreheadWidth: Double?
    var mouthWidth: Double?
    var eyeWidth: Double?
    var innerEyeGap: Double?
    var noseProjection: Double?
    /// Relative to ARKit's average face: +0.05 means 5% more than average.
    var lengthVsAverage: Double
    var jawVsAverage: Double?
    var foreheadVsAverage: Double?
}

enum FaceShapeAnalyzer {
    private struct Measurements {
        var length: Float
        var cheek: Float
        var jaw: Float?
        var forehead: Float?
        var mouth: Float?
        var eyeWidth: Float?
        var innerEyeGap: Float?
        var noseProjection: Float?
    }

    private struct Loop {
        let points: [SIMD3<Float>]
        let centroid: SIMD3<Float>
        let minX: Float
        let maxX: Float

        init(points: [SIMD3<Float>]) {
            self.points = points
            centroid = points.reduce(SIMD3<Float>.zero, +) / Float(max(points.count, 1))
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
        guard let user = measure(vertices: vertices, indices: mesh.triangleIndices),
              let average = averageFace() else { return nil }

        let lengthRatio = user.length / user.cheek
        let averageLengthRatio = average.length / average.cheek
        let lengthDelta = Double(lengthRatio / averageLengthRatio - 1)

        var jawDelta: Double?
        if let jaw = user.jaw, let averageJaw = average.jaw {
            jawDelta = Double((jaw / user.cheek) / (averageJaw / average.cheek) - 1)
        }
        var foreheadDelta: Double?
        if let forehead = user.forehead, let averageForehead = average.forehead {
            foreheadDelta = Double((forehead / user.cheek) / (averageForehead / average.cheek) - 1)
        }

        return FaceGeometryReport(
            shape: classify(length: lengthDelta, jaw: jawDelta ?? 0, forehead: foreheadDelta ?? 0),
            faceLength: mm(user.length),
            cheekWidth: mm(user.cheek),
            jawWidth: user.jaw.map(mm),
            foreheadWidth: user.forehead.map(mm),
            mouthWidth: user.mouth.map(mm),
            eyeWidth: user.eyeWidth.map(mm),
            innerEyeGap: user.innerEyeGap.map(mm),
            noseProjection: user.noseProjection.map(mm),
            lengthVsAverage: lengthDelta,
            jawVsAverage: jawDelta,
            foreheadVsAverage: foreheadDelta
        )
    }

    // MARK: - Classification

    private static func classify(length: Double, jaw: Double, forehead: Double) -> FaceShape {
        if forehead > 0.03 && jaw < -0.04 { return .heart }
        if forehead < -0.04 && jaw < -0.04 { return .diamond }
        if jaw > 0.05 && length < 0.04 { return .square }
        if length > 0.06 { return .oblong }
        if length < -0.05 { return .round }
        return .oval
    }

    private static func mm(_ metres: Float) -> Double { Double(metres) * 1000 }

    /// ARKit's generic neutral face, measured once, as the "average" baseline.
    private static func averageFace() -> Measurements? {
        if !referenceMeasured {
            referenceMeasured = true
            if let geometry = ARFaceGeometry(blendShapes: [:]) {
                reference = measure(vertices: geometry.vertices, indices: geometry.triangleIndices)
            }
        }
        return reference
    }

    // MARK: - Measurement

    private static func measure(vertices: [SIMD3<Float>], indices: [Int16]) -> Measurements? {
        guard vertices.count > 100, indices.count >= 3 else { return nil }
        let loops = boundaryComponents(indices: indices, vertexCount: vertices.count)
            .map { Loop(points: $0.map { vertices[$0] }) }
        // The face outline is the widest open boundary; eyes and mouth are the holes inside it.
        guard let outlineIndex = loops.indices.max(by: { loops[$0].width < loops[$1].width }),
              let noseTip = vertices.max(by: { $0.z < $1.z }) else { return nil }
        let outline = loops[outlineIndex]
        let holes = loops.indices.filter { $0 != outlineIndex }.map { loops[$0] }

        let eyes = holes
            .filter { $0.centroid.y > noseTip.y + 0.01 }
            .sorted { $0.points.count > $1.points.count }
            .prefix(2)
        let mouth = holes
            .filter { $0.centroid.y < noseTip.y - 0.005 && abs($0.centroid.x) < 0.015 }
            .max { $0.points.count < $1.points.count }

        let middle = outline.points.filter { abs($0.x) < 0.02 }
        guard let chinY = middle.map(\.y).min(), let topY = middle.map(\.y).max(), topY - chinY > 0.05 else {
            return nil
        }

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

        let eyeY = eyes.isEmpty ? noseTip.y + 0.035 : eyes.map(\.centroid.y).reduce(0, +) / Float(eyes.count)
        let mouthY = mouth?.centroid.y ?? noseTip.y - 0.025

        var cheek: Float = 0
        var y = noseTip.y
        while y <= eyeY {
            if let w = width(at: y) { cheek = Swift.max(cheek, w) }
            y += 0.003
        }
        guard cheek > 0.05 else { return nil }

        var result = Measurements(length: topY - chinY, cheek: cheek)
        result.forehead = width(at: eyeY + 0.55 * (topY - eyeY))
        result.jaw = width(at: mouthY - 0.35 * (mouthY - chinY))
        result.mouth = mouth?.width

        if !eyes.isEmpty {
            result.eyeWidth = eyes.map(\.width).reduce(0, +) / Float(eyes.count)
            let eyeZ = eyes.flatMap(\.points).map(\.z).reduce(0, +) / Float(eyes.flatMap(\.points).count)
            result.noseProjection = noseTip.z - eyeZ
        }
        if eyes.count == 2 {
            let leftEye = eyes.max { $0.centroid.x < $1.centroid.x }
            let rightEye = eyes.min { $0.centroid.x < $1.centroid.x }
            if let leftEye, let rightEye {
                result.innerEyeGap = leftEye.minX - rightEye.maxX
            }
        }
        return result
    }

    /// Groups the mesh's open-boundary vertices (edges used by only one triangle) into connected loops.
    private static func boundaryComponents(indices: [Int16], vertexCount: Int) -> [[Int]] {
        func key(_ a: Int, _ b: Int) -> UInt64 {
            (UInt64(Swift.min(a, b)) << 32) | UInt64(Swift.max(a, b))
        }

        var edgeUse: [UInt64: Int] = [:]
        edgeUse.reserveCapacity(indices.count)
        var t = 0
        while t + 2 < indices.count {
            let a = Int(indices[t]), b = Int(indices[t + 1]), c = Int(indices[t + 2])
            edgeUse[key(a, b), default: 0] += 1
            edgeUse[key(b, c), default: 0] += 1
            edgeUse[key(c, a), default: 0] += 1
            t += 3
        }

        var neighbours: [Int: [Int]] = [:]
        for (edge, count) in edgeUse where count == 1 {
            let a = Int(edge >> 32)
            let b = Int(edge & 0xFFFF_FFFF)
            guard a >= 0, b >= 0, a < vertexCount, b < vertexCount else { continue }
            neighbours[a, default: []].append(b)
            neighbours[b, default: []].append(a)
        }

        var seen = Set<Int>()
        var components: [[Int]] = []
        for start in neighbours.keys where !seen.contains(start) {
            var stack = [start]
            seen.insert(start)
            var component: [Int] = []
            while let vertex = stack.popLast() {
                component.append(vertex)
                for next in neighbours[vertex] ?? [] where !seen.contains(next) {
                    seen.insert(next)
                    stack.append(next)
                }
            }
            if component.count >= 6 {
                components.append(component)
            }
        }
        return components
    }
}
