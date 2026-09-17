import SwiftUI
import simd

/// Drag-to-rotate 3D face mesh, coloured by how far each area is from its mirror image.
/// Rendered with a painter's algorithm in a SwiftUI Canvas — no SceneKit needed.
struct MeshHeatmapView: View {
    static let maxDeviationMM: Float = 4

    private let vertices: [SIMD3<Float>]
    private let triangles: [(Int, Int, Int)]
    /// Per-triangle heat colour components, precomputed once.
    private let heat: [SIMD3<Float>]
    private let extent: Float

    @State private var yaw: Double = 0.4
    @State private var pitch: Double = -0.1
    @State private var baseYaw: Double = 0.4
    @State private var basePitch: Double = -0.1

    init(mesh: MeshSnapshot) {
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(mesh.vertexCount)
        for i in 0..<mesh.vertexCount {
            points.append(SIMD3<Float>(mesh.vertices[i * 3], mesh.vertices[i * 3 + 1], mesh.vertices[i * 3 + 2]))
        }
        // Centre the mesh so it rotates around its own middle.
        if let first = points.first {
            var lo = first, hi = first
            for p in points {
                lo = simd_min(lo, p)
                hi = simd_max(hi, p)
            }
            let centre = (lo + hi) / 2
            points = points.map { $0 - centre }
            extent = max(hi.x - lo.x, hi.y - lo.y)
        } else {
            extent = 0.2
        }
        vertices = points

        let count = points.count
        var tris: [(Int, Int, Int)] = []
        var colours: [SIMD3<Float>] = []
        let indices = mesh.triangleIndices
        var t = 0
        while t + 2 < indices.count {
            let a = Int(indices[t]), b = Int(indices[t + 1]), c = Int(indices[t + 2])
            t += 3
            guard a < count, b < count, c < count else { continue }
            tris.append((a, b, c))
            let deviation: Float
            if mesh.deviation.count == count {
                deviation = (mesh.deviation[a] + mesh.deviation[b] + mesh.deviation[c]) / 3 * 1000
            } else {
                deviation = 0
            }
            colours.append(Self.heatColour(deviation / Self.maxDeviationMM))
        }
        triangles = tris
        heat = colours
    }

    var body: some View {
        Canvas { context, size in
            render(in: &context, size: size)
        }
        .drawingGroup()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    yaw = baseYaw + Double(value.translation.width) / 140
                    pitch = min(0.9, max(-0.9, basePitch + Double(value.translation.height) / 140))
                }
                .onEnded { _ in
                    baseYaw = yaw
                    basePitch = pitch
                }
        )
    }

    // MARK: - Rendering

    private func render(in context: inout GraphicsContext, size: CGSize) {
        guard !vertices.isEmpty, extent > 0 else { return }
        let cy = Float(cos(yaw)), sy = Float(sin(yaw))
        let cp = Float(cos(pitch)), sp = Float(sin(pitch))
        let scale = Float(min(size.width, size.height)) / (extent * 1.15)
        let midX = Float(size.width) / 2
        let midY = Float(size.height) / 2

        // Rotate: yaw about Y, then pitch about X. Viewer looks from +Z.
        var rotated = [SIMD3<Float>](repeating: .zero, count: vertices.count)
        for (i, v) in vertices.enumerated() {
            let x1 = v.x * cy + v.z * sy
            let z1 = -v.x * sy + v.z * cy
            let y2 = v.y * cp - z1 * sp
            let z2 = v.y * sp + z1 * cp
            rotated[i] = SIMD3<Float>(x1, y2, z2)
        }

        func screen(_ p: SIMD3<Float>) -> CGPoint {
            CGPoint(x: CGFloat(midX + p.x * scale), y: CGFloat(midY - p.y * scale))
        }

        guard !triangles.isEmpty else {
            for p in rotated {
                let s = screen(p)
                context.fill(Path(ellipseIn: CGRect(x: s.x - 1, y: s.y - 1, width: 2, height: 2)), with: .color(Theme.accent))
            }
            return
        }

        // Painter's algorithm: draw far triangles first.
        let depths = triangles.map { rotated[$0.0].z + rotated[$0.1].z + rotated[$0.2].z }
        let order = triangles.indices.sorted { depths[$0] < depths[$1] }

        for index in order {
            let (a, b, c) = triangles[index]
            let pa = rotated[a], pb = rotated[b], pc = rotated[c]
            let normal = simd_normalize(simd_cross(pb - pa, pc - pa))
            let light = 0.3 + 0.7 * abs(normal.z.isNaN ? 1 : normal.z)
            let rgb = heat[index] * light
            let colour = Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))

            var path = Path()
            path.move(to: screen(pa))
            path.addLine(to: screen(pb))
            path.addLine(to: screen(pc))
            path.closeSubpath()
            context.fill(path, with: .color(colour))
            // A hairline in the same colour hides anti-aliasing seams between triangles.
            context.stroke(path, with: .color(colour), lineWidth: 0.6)
        }
    }

    /// 0 = symmetric (teal) → 0.5 (amber) → 1+ = asymmetric (red).
    static func heatColour(_ t: Float) -> SIMD3<Float> {
        let low = SIMD3<Float>(0.30, 0.85, 0.78)
        let mid = SIMD3<Float>(1.00, 0.80, 0.35)
        let high = SIMD3<Float>(1.00, 0.32, 0.40)
        let x = min(1, max(0, t))
        return x < 0.5
            ? simd_mix(low, mid, SIMD3<Float>(repeating: x * 2))
            : simd_mix(mid, high, SIMD3<Float>(repeating: (x - 0.5) * 2))
    }
}

struct HeatmapLegend: View {
    var body: some View {
        VStack(spacing: 4) {
            LinearGradient(
                colors: [0, 0.5, 1].map { t in
                    let c = MeshHeatmapView.heatColour(Float(t))
                    return Color(red: Double(c.x), green: Double(c.y), blue: Double(c.z))
                },
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())
            HStack {
                Text("Symmetric")
                Spacer()
                Text("\(Int(MeshHeatmapView.maxDeviationMM))+ mm difference")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
