import SwiftUI

/// Scores for each area of the face with a one-line insight.
struct RegionScoresCard: View {
    let scores: [RegionScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Face analysis", subtitle: "How each area of your face scored")
            ForEach(scores) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.region.symbol)
                        .font(.headline)
                        .foregroundStyle(item.region.color)
                        .frame(width: 36, height: 36)
                        .background(item.region.color.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.region.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(item.score.map { "\(Int($0.rounded()))" } ?? "–")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(item.score.map { Theme.color(forScore: $0) } ?? Color.secondary)
                        }
                        ProgressView(value: min(1, max(0, (item.score ?? 0) / 100)))
                            .tint(item.region.color)
                        Text(item.insight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }
}

/// Face shape estimate and 3D proportions from the TrueDepth mesh.
struct FaceShapeCard: View {
    let report: FaceGeometryReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Face shape & proportions", subtitle: "Measured in 3D by the TrueDepth camera")

            if let report {
                HStack(spacing: 14) {
                    Image(systemName: report.shape.symbol)
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 60, height: 60)
                        .background(Theme.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(report.shape.title) face shape")
                            .font(.title3.bold())
                        Text(report.shape.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    comparisonRow("Face length", report.lengthVsAverage)
                    if let jaw = report.jawVsAverage {
                        comparisonRow("Jaw width", jaw)
                    }
                    if let forehead = report.foreheadVsAverage {
                        comparisonRow("Forehead width", forehead)
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    measurementRow("Cheekbone width", report.cheekWidth)
                    measurementRow("Jaw width", report.jawWidth)
                    measurementRow("Forehead width", report.foreheadWidth)
                    measurementRow("Chin to upper forehead", report.faceLength)
                    measurementRow("Mouth width", report.mouthWidth)
                    measurementRow("Eye width", report.eyeWidth)
                    measurementRow("Gap between eyes", report.innerEyeGap)
                    measurementRow("Nose projection", report.noseProjection)
                }

                if let gap = report.innerEyeGap, let eye = report.eyeWidth, eye > 0 {
                    Text(eyeSpacingNote(gap / eye))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Shape is an estimate compared with ARKit's average face model. Exercises train muscle tone and control; they don't change bone structure.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Label("Face shape needs a scan from an iPhone with a TrueDepth camera.", systemImage: "cube.transparent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func comparisonRow(_ title: String, _ delta: Double) -> some View {
        let percent = Int((delta * 100).rounded())
        let text: String
        if abs(percent) < 2 {
            text = "About average"
        } else if percent > 0 {
            text = "\(percent)% more than average"
        } else {
            text = "\(-percent)% less than average"
        }
        return HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(abs(percent) < 2 ? Color.secondary : Theme.secondary)
        }
    }

    private func measurementRow(_ title: String, _ value: Double?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.map { String(format: "%.0f mm", $0) } ?? "—")
                .font(.subheadline.monospacedDigit())
        }
    }

    private func eyeSpacingNote(_ ratio: Double) -> String {
        switch ratio {
        case ..<0.85: "Your eyes are set a little closer than one eye-width apart."
        case 0.85...1.15: "The gap between your eyes is about one eye-width, a classic balanced proportion."
        default: "Your eyes are set a little wider than one eye-width apart."
        }
    }
}
