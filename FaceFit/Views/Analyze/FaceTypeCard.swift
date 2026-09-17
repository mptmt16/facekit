import SwiftUI

/// Scientific face type (Martin–Saller facial index) and 3D measurements from the TrueDepth mesh.
struct FaceShapeCard: View {
    let report: FaceGeometryReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Face type", subtitle: "Anthropometric facial index, measured in 3D")

            if let report {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.facialIndexClass.name)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.secondary)
                    Text("\(report.facialIndexClass.meaning) · facial index \(report.facialIndex, specifier: "%.1f")")
                        .font(.subheadline)
                }

                FacialIndexScale(index: report.facialIndex, averageIndex: report.averageFacialIndex)

                if let upper = report.upperFacialIndex, let upperClass = report.upperFacialIndexClass {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Upper facial index")
                            .font(.subheadline)
                        Spacer()
                        Text("\(upperClass.name) · \(upper, specifier: "%.1f")")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("A \(upperClass.meaning), from nasion to where the lips meet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(spacing: 8) {
                    measurementRow("Face height (nasion–menton)", report.faceHeight)
                    measurementRow("Face width (bizygomatic)", report.bizygomaticWidth)
                    measurementRow("Upper face height (nasion–stomion)", report.upperFaceHeight)
                    measurementRow("Jaw width", report.jawWidth, comparedWithAverage: report.jawVsAverage)
                    measurementRow("Forehead width", report.foreheadWidth, comparedWithAverage: report.foreheadVsAverage)
                    measurementRow("Mouth width", report.mouthWidth)
                    measurementRow("Eye width", report.eyeWidth)
                    measurementRow("Gap between eyes", report.innerEyeGap)
                    measurementRow("Nose projection", report.noseProjection)
                }

                Text("The facial index (face height ÷ face width × 100) is the classification used in physical anthropology (Martin & Saller). Labels like oval, heart or square come from beauty and fashion guides and have no scientific definition. Landmarks are located automatically on the soft-tissue mesh, so values can differ by a few percent from caliper measurements.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Label("Face type needs a scan from an iPhone with a TrueDepth camera.", systemImage: "cube.transparent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func measurementRow(_ title: String, _ value: Double?, comparedWithAverage delta: Double? = nil) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if let delta, abs(delta) >= 0.02 {
                Text(delta > 0 ? "+\(Int((delta * 100).rounded()))% vs avg" : "\(Int((delta * 100).rounded()))% vs avg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value.map { String(format: "%.0f mm", $0) } ?? "—")
                .font(.subheadline.monospacedDigit())
        }
    }
}

/// Five-band scale for the facial index, marking the user's value and ARKit's average face.
struct FacialIndexScale: View {
    let index: Double
    var averageIndex: Double?

    private let lower = 75.0
    private let upper = 100.0

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 2) {
                        ForEach(Array(FacialIndexClass.allCases.enumerated()), id: \.offset) { position, kind in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(kind == FacialIndexClass(index: index) ? Theme.secondary : Color.white.opacity(0.12))
                                .frame(width: bandWidth(position, total: width))
                        }
                    }
                    .frame(height: 10)
                    .padding(.top, 8)

                    if let averageIndex {
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 2, height: 18)
                            .offset(x: x(for: averageIndex, width: width) - 1, y: 4)
                    }

                    Circle()
                        .fill(Theme.warm)
                        .frame(width: 14, height: 14)
                        .offset(x: x(for: index, width: width) - 7, y: 6)
                }
            }
            .frame(height: 26)

            HStack {
                ForEach(FacialIndexClass.allCases, id: \.self) { kind in
                    Text(kind.shortName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(kind == FacialIndexClass(index: index) ? Theme.secondary : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            if averageIndex != nil {
                Text("● you   | ARKit average face")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Bands are drawn over 75–100: <80, 80–85, 85–90, 90–95, ≥95.
    private func bandWidth(_ position: Int, total: CGFloat) -> CGFloat {
        let edges = [lower, 80, 85, 90, 95, upper]
        let span = edges[position + 1] - edges[position]
        return Swift.max(0, total * CGFloat(span / (upper - lower)) - 2)
    }

    private func x(for value: Double, width: CGFloat) -> CGFloat {
        let clamped = Swift.min(upper, Swift.max(lower, value))
        return width * CGFloat((clamped - lower) / (upper - lower))
    }
}
