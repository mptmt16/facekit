import Foundation

/// Topology helpers for ARKit's face mesh.
enum MeshTopology {
    /// The mesh's open boundaries as ordered vertex loops: the face outline plus the
    /// eye and mouth openings. An edge used by only one triangle is a boundary edge.
    static func boundaryLoops(indices: [Int16], vertexCount: Int) -> [[Int]] {
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

        var visited = Set<Int>()
        var loops: [[Int]] = []
        for start in neighbours.keys.sorted() where !visited.contains(start) {
            var loop = [start]
            visited.insert(start)
            var previous = -1
            var current = start
            while let next = (neighbours[current] ?? []).first(where: { $0 != previous && !visited.contains($0) }) {
                loop.append(next)
                visited.insert(next)
                previous = current
                current = next
            }
            if loop.count >= 6 {
                loops.append(loop)
            }
        }
        return loops
    }
}
