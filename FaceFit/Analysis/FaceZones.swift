import simd

/// Splits the ARKit face mesh into skin zones using landmarks found on the mesh itself.
enum FaceZones {
    struct Layout {
        var zones: [SkinZone: [Int]]
        /// Vertex indices around the eyes and mouth, excluded from skin analysis.
        var excluded: Set<Int>
    }

    static func layout(vertices: [SIMD3<Float>], indices: [Int16]) -> Layout? {
        guard vertices.count > 100 else { return nil }
        let loops = MeshTopology.boundaryLoops(indices: indices, vertexCount: vertices.count)
        guard !loops.isEmpty else { return nil }

        let loopPoints = loops.map { loop in loop.map { vertices[$0] } }
        guard let outlineIndex = loopPoints.indices.max(by: { extentX(loopPoints[$0]) < extentX(loopPoints[$1]) }),
              let noseTip = vertices.filter({ abs($0.x) < 0.015 }).max(by: { $0.z < $1.z }) else { return nil }

        let holes = loopPoints.indices.filter { $0 != outlineIndex }
        let eyeLoops = holes
            .filter { centroid(loopPoints[$0]).y > noseTip.y + 0.01 }
            .sorted { loopPoints[$0].count > loopPoints[$1].count }
            .prefix(2)
            .map { loopPoints[$0] }
        let mouthLoop = holes
            .filter { centroid(loopPoints[$0]).y < noseTip.y - 0.005 && abs(centroid(loopPoints[$0]).x) < 0.015 }
            .max { loopPoints[$0].count < loopPoints[$1].count }
            .map { loopPoints[$0] }

        let eyeY = eyeLoops.isEmpty
            ? noseTip.y + 0.035
            : eyeLoops.map { centroid($0).y }.reduce(0, +) / Float(eyeLoops.count)
        let mouthY = mouthLoop.map { centroid($0).y } ?? noseTip.y - 0.025
        let outline = loopPoints[outlineIndex]
        let topY = outline.filter { abs($0.x) < 0.02 }.map(\.y).max() ?? eyeY + 0.05
        let chinY = outline.filter { abs($0.x) < 0.02 }.map(\.y).min() ?? mouthY - 0.05
        let halfWidth = Swift.max(0.05, (outline.map(\.x).max() ?? 0.07) - centroid(outline).x)

        // Eyes, brows and lips are not skin we can score, so they stay out of every zone.
        var excluded = Set<Int>()
        for (index, vertex) in vertices.enumerated() {
            for eye in eyeLoops {
                let eyeCentre = centroid(eye)
                if abs(vertex.x - eyeCentre.x) < 0.028,
                   vertex.y > eyeCentre.y - 0.006,
                   vertex.y < eyeCentre.y + 0.030 {
                    excluded.insert(index)
                }
            }
            if let mouth = mouthLoop {
                let mouthCentre = centroid(mouth)
                if abs(vertex.x - mouthCentre.x) < 0.045, abs(vertex.y - mouthCentre.y) < 0.022 {
                    excluded.insert(index)
                }
            }
        }

        var zones: [SkinZone: [Int]] = [:]
        for zone in SkinZone.allCases {
            let members = vertices.indices.filter { index in
                guard !excluded.contains(index) else { return false }
                let v = vertices[index]
                switch zone {
                case .forehead:
                    return v.y > eyeY + 0.020 && v.y < topY - 0.004 && abs(v.x) < halfWidth * 0.62
                case .underEyes:
                    guard !eyeLoops.isEmpty else { return false }
                    return eyeLoops.contains { eye in
                        let centre = centroid(eye)
                        return abs(v.x - centre.x) < 0.022 && v.y < centre.y - 0.007 && v.y > centre.y - 0.026
                    }
                case .nose:
                    return abs(v.x) < 0.017 && v.y < eyeY - 0.012 && v.y > noseTip.y - 0.010
                case .leftCheek:
                    return v.x > 0.020 && v.y < eyeY - 0.024 && v.y > noseTip.y - 0.016
                case .rightCheek:
                    return v.x < -0.020 && v.y < eyeY - 0.024 && v.y > noseTip.y - 0.016
                case .chin:
                    return v.y < mouthY - 0.014 && v.y > chinY + 0.004 && abs(v.x) < 0.040
                }
            }
            if members.count >= 8 {
                zones[zone] = members
            }
        }
        guard !zones.isEmpty else { return nil }
        return Layout(zones: zones, excluded: excluded)
    }

    private static func centroid(_ points: [SIMD3<Float>]) -> SIMD3<Float> {
        points.reduce(SIMD3<Float>.zero, +) / Float(Swift.max(points.count, 1))
    }

    private static func extentX(_ points: [SIMD3<Float>]) -> Float {
        (points.map(\.x).max() ?? 0) - (points.map(\.x).min() ?? 0)
    }
}
