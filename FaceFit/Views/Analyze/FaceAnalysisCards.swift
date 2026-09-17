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

