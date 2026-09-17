import SwiftUI

/// Face Score headline: overall score, level, change since the last scan, radar and pillar breakdown.
struct FaceScoreCard: View {
    let breakdown: FaceScoreBreakdown
    var previous: FaceScoreBreakdown?
    var date: Date

    @State private var shareImage: Image?

    private var level: FaceLevel { FaceLevel(score: breakdown.overall) }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                ScoreGauge(score: breakdown.overall, title: "", size: 112, lineWidth: 12)
                VStack(alignment: .leading, spacing: 6) {
                    Text("FACE SCORE")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Label(level.title, systemImage: level.symbol)
                        .font(.title3.bold())
                        .foregroundStyle(level.color)
                    if let next = level.next {
                        Text("\(Int((next.minimumScore - breakdown.overall).rounded(.up))) points to \(next.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Top level reached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let previous {
                        DeltaBadge(delta: breakdown.overall - previous.overall)
                    }
                }
                Spacer(minLength: 0)
            }

            RadarChart(
                axes: FacePillar.allCases.map { pillar in
                    RadarChart.Axis(id: pillar.id, label: pillar.title, value: (breakdown.value(for: pillar) ?? 0) / 100)
                },
                previous: previous.map { old in
                    FacePillar.allCases.map { (old.value(for: $0) ?? 0) / 100 }
                }
            )
            .frame(height: 230)

            if previous != nil {
                Label("Dashed line: your previous scan", systemImage: "line.diagonal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                ForEach(FacePillar.allCases) { pillar in
                    PillarRow(pillar: pillar,
                              value: breakdown.value(for: pillar),
                              previous: previous?.value(for: pillar),
                              isFocus: pillar == breakdown.weakest)
                }
            }

            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview("My FaceFit score", image: shareImage)) {
                    Label("Share score card", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .card()
        .onAppear(perform: renderShareImage)
    }

    @MainActor
    private func renderShareImage() {
        guard shareImage == nil else { return }
        let renderer = ImageRenderer(content: ScoreShareCard(breakdown: breakdown, date: date))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

struct DeltaBadge: View {
    let delta: Double

    var body: some View {
        let change = Int(delta.rounded())
        Label(change == 0 ? "Same as last scan" : "\(change > 0 ? "+" : "")\(change) since last scan",
              systemImage: change > 0 ? "arrow.up.right" : (change < 0 ? "arrow.down.right" : "equal"))
            .font(.caption.bold())
            .foregroundStyle(change > 0 ? Color.green : (change < 0 ? Color.orange : Color.secondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

struct PillarRow: View {
    let pillar: FacePillar
    let value: Double?
    let previous: Double?
    var isFocus = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(pillar.title, systemImage: pillar.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(pillar.color)
                if isFocus {
                    Text("FOCUS")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warm.opacity(0.25), in: Capsule())
                        .foregroundStyle(Theme.warm)
                }
                Spacer()
                if let value {
                    if let previous {
                        let change = Int((value - previous).rounded())
                        if change != 0 {
                            Text(change > 0 ? "+\(change)" : "\(change)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(change > 0 ? Color.green : Color.orange)
                        }
                    }
                    Text("\(Int(value.rounded()))")
                        .font(.subheadline.bold().monospacedDigit())
                } else {
                    Text("Scan again to measure")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: min(1, max(0, (value ?? 0) / 100)))
                .tint(pillar.color)
            Text(pillar.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// A static card rendered to an image for sharing. It contains scores only, never face data.
struct ScoreShareCard: View {
    let breakdown: FaceScoreBreakdown
    let date: Date

    var body: some View {
        let level = FaceLevel(score: breakdown.overall)
        VStack(spacing: 18) {
            HStack {
                Label("FaceFit", systemImage: "faceid")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(date, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ScoreGauge(score: breakdown.overall, title: "", size: 150, lineWidth: 16)
            Label(level.title, systemImage: level.symbol)
                .font(.title2.bold())
                .foregroundStyle(level.color)
            HStack(spacing: 10) {
                ForEach(FacePillar.allCases) { pillar in
                    VStack(spacing: 4) {
                        Text(breakdown.value(for: pillar).map { "\(Int($0.rounded()))" } ?? "–")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(pillar.color)
                        Text(pillar.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Measured in 3D with the iPhone TrueDepth camera")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 380)
        .background(
            LinearGradient(colors: [Color(red: 0.06, green: 0.20, blue: 0.22), Color(white: 0.04)],
                           startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .dark)
    }
}
