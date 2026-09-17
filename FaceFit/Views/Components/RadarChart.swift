import SwiftUI

/// Spider chart for the Face Score pillars, with an optional dashed overlay for the previous scan.
struct RadarChart: View {
    struct Axis: Identifiable {
        let id: String
        let label: String
        /// 0...1
        let value: Double
    }

    let axes: [Axis]
    /// Previous values (0...1) in the same order as `axes`.
    var previous: [Double]?
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = max(10, size / 2 - 36)

            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    polygon(Array(repeating: Double(ring) / 4, count: axes.count), center: center, radius: radius)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

                Path { path in
                    for index in axes.indices {
                        path.move(to: center)
                        path.addLine(to: point(index, value: 1, center: center, radius: radius))
                    }
                }
                .stroke(Color.white.opacity(0.12), lineWidth: 1)

                if let previous, previous.count == axes.count {
                    polygon(previous, center: center, radius: radius)
                        .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }

                polygon(axes.map(\.value), center: center, radius: radius)
                    .fill(color.opacity(0.25))
                polygon(axes.map(\.value), center: center, radius: radius)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

                ForEach(Array(axes.enumerated()), id: \.element.id) { index, axis in
                    VStack(spacing: 1) {
                        Text(axis.label)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Text("\(Int((axis.value * 100).rounded()))")
                            .font(.caption.bold().monospacedDigit())
                    }
                    .position(point(index, value: 1.3, center: center, radius: radius))
                }
            }
        }
    }

    private func point(_ index: Int, value: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(axes.count, 1))
        return CGPoint(
            x: center.x + CGFloat(cos(angle) * value) * radius,
            y: center.y + CGFloat(sin(angle) * value) * radius
        )
    }

    private func polygon(_ values: [Double], center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for (index, value) in values.enumerated() {
                let clamped = min(1, max(0.03, value))
                let corner = point(index, value: clamped, center: center, radius: radius)
                if index == 0 {
                    path.move(to: corner)
                } else {
                    path.addLine(to: corner)
                }
            }
            path.closeSubpath()
        }
    }
}
