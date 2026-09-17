import ARKit
import simd

/// Geometry helpers for ARKit's 1,220-vertex face mesh.
enum FaceMeshMath {
    private static var cachedMirrorMap: [Int]?

    /// For every vertex, the index of its mirror-image partner across the face's midline (x = 0).
    ///
    /// Built from ARKit's neutral reference face so the pairing is not skewed by the
    /// user's own asymmetry. Falls back to the supplied mesh if the reference is unavailable.
    static func mirrorMap(fallback vertices: [SIMD3<Float>]) -> [Int] {
        if let cached = cachedMirrorMap, cached.count == vertices.count {
            return cached
        }
        let reference = ARFaceGeometry(blendShapes: [:])?.vertices ?? vertices
        guard reference.count == vertices.count else {
            return Array(vertices.indices)
        }
        var map = [Int](repeating: 0, count: reference.count)
        reference.withUnsafeBufferPointer { points in
            for i in 0..<points.count {
                let mirrored = SIMD3<Float>(-points[i].x, points[i].y, points[i].z)
                var best = i
                var bestDistance = Float.greatestFiniteMagnitude
                for j in 0..<points.count {
                    let d = simd_distance_squared(mirrored, points[j])
                    if d < bestDistance {
                        bestDistance = d
                        best = j
                    }
                }
                map[i] = best
            }
        }
        cachedMirrorMap = map
        return map
    }

    /// Per-vertex asymmetry in metres: how far each vertex is from the mirror image of its partner.
    /// The mirror plane is re-centred on the mesh so a small offset in ARKit's midline is not counted.
    static func asymmetry(of vertices: [SIMD3<Float>]) -> [Float] {
        guard !vertices.isEmpty else { return [] }
        let map = mirrorMap(fallback: vertices)
        let centreX = vertices.reduce(Float(0)) { $0 + $1.x } / Float(vertices.count)
        return vertices.indices.map { i in
            let partner = vertices[map[i]]
            let reflected = SIMD3<Float>(2 * centreX - partner.x, partner.y, partner.z)
            return simd_distance(vertices[i], reflected)
        }
    }

    struct Bounds {
        var width: Float
        var height: Float
        var depth: Float
    }

    static func bounds(of vertices: [SIMD3<Float>]) -> Bounds? {
        guard let first = vertices.first else { return nil }
        var lo = first
        var hi = first
        for v in vertices {
            lo = simd_min(lo, v)
            hi = simd_max(hi, v)
        }
        let size = hi - lo
        return Bounds(width: size.x, height: size.y, depth: size.z)
    }
}
