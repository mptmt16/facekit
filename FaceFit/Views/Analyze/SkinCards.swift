import SwiftUI

/// Headline skin score with the counts and measurements behind it.
struct SkinScoreCard: View {
    let report: SkinReport

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ScoreGauge(score: report.overall, title: "", size: 104, lineWidth: 11)
                VStack(alignment: .leading, spacing: 6) {
                    Text("SKIN SCORE")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(headline)
                        .font(.title3.bold())
                    Text("Measured from your scan photo on this iPhone. Nothing is uploaded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                countChip("\(report.blemishCount)", "Blemishes", Color(red: 1.0, green: 0.35, blue: 0.45))
                countChip("\(report.darkSpotCount)", "Dark spots", Color(red: 1.0, green: 0.78, blue: 0.30))
                countChip("\(report.lineCount)", "Fine lines", Theme.secondary)
            }

            VStack(spacing: 12) {
                ForEach(report.metrics) { metric in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Label(metric.title, systemImage: metric.symbol)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(metric.score.rounded()))")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Theme.color(forScore: metric.score))
                        }
                        ProgressView(value: min(1, max(0, metric.score / 100)))
                            .tint(Theme.color(forScore: metric.score))
                        Text(metric.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }

    private var headline: String {
        switch report.overall {
        case 85...: "Clear and even"
        case 70..<85: "Healthy, minor issues"
        case 55..<70: "A few things to work on"
        default: "Needs attention"
        }
    }

    private func countChip(_ value: String, _ title: String, _ colour: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(colour)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(colour.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Face map plus a score for each zone, with the zoomed crops we found things in.
struct SkinZonesCard: View {
    let report: SkinReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Zone map", subtitle: "\(report.zones.count) face zones, scored separately")

            ZStack {
                Ellipse()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 150, height: 200)
                GeometryReader { proxy in
                    ForEach(report.zones) { zone in
                        let position = zone.zone.mapPosition
                        Circle()
                            .fill(Theme.color(forScore: zone.score))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 2))
                            .position(x: proxy.size.width / 2 + (position.x - 0.5) * 150,
                                      y: proxy.size.height / 2 + (position.y - 0.5) * 200)
                    }
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)

            ForEach(report.zones) { zone in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: zone.zone.symbol)
                            .foregroundStyle(Theme.color(forScore: zone.score))
                            .frame(width: 32, height: 32)
                            .background(Theme.color(forScore: zone.score).opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.zone.title).font(.subheadline.weight(.semibold))
                            Text(zone.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(zone.score.rounded()))")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(Theme.color(forScore: zone.score))
                    }
                    if let data = zone.cropJPEG, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text("Circled: \(zone.blemishes) blemishes, \(zone.darkSpots) dark spots")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }
}

/// What to do about it, in plain language.
struct SkinTipsCard: View {
    let report: SkinReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Skin recommendations", subtitle: "Wellness guidance, not medical advice")
            ForEach(Array(report.recommendations.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(Theme.secondary.opacity(0.2), in: Circle())
                    Text(tip)
                        .font(.subheadline)
                }
            }
            Text("Lighting, camera angle and makeup all affect these numbers. Scan in similar light each time, and see a dermatologist for anything painful, changing or persistent.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}
