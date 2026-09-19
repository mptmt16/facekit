import SwiftUI
import SwiftData

/// Before and after: two scans side by side with what changed.
struct CompareScansView: View {
    @Query(sort: \FaceScan.date, order: .reverse) private var scans: [FaceScan]
    @State private var beforeDate: Date?
    @State private var afterDate: Date?

    private var before: FaceScan? {
        beforeDate.flatMap { date in scans.first { $0.date == date } } ?? scans.last
    }

    private var after: FaceScan? {
        afterDate.flatMap { date in scans.first { $0.date == date } } ?? scans.first
    }

    var body: some View {
        ScrollView {
            if scans.count < 2 {
                ContentUnavailableView("Two scans needed",
                                       systemImage: "rectangle.on.rectangle",
                                       description: Text("Take another face scan to compare. A week or two apart shows real change; day to day is mostly lighting."))
                    .padding(.top, 60)
            } else if let before, let after {
                VStack(spacing: 20) {
                    photoRow(before: before, after: after)
                    scoreCard(before: before, after: after)
                    skinCard(before: before, after: after)
                    regionCard(before: before, after: after)
                    Text("Compare scans taken in similar light. Muscle tone and skin both take 4–8 weeks of consistent work to shift meaningfully.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .navigationTitle("Before & after")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if scans.count >= 2 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Before", selection: $beforeDate) {
                            ForEach(scans) { scan in
                                Text(scan.date, format: .dateTime.day().month().year()).tag(Date?.some(scan.date))
                            }
                        }
                        Picker("After", selection: $afterDate) {
                            ForEach(scans) { scan in
                                Text(scan.date, format: .dateTime.day().month().year()).tag(Date?.some(scan.date))
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private func photoRow(before: FaceScan, after: FaceScan) -> some View {
        let days = Calendar.current.dateComponents([.day], from: before.date, to: after.date).day ?? 0
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                photo(for: before, label: "Before")
                photo(for: after, label: "After")
            }
            Text(days > 0 ? "\(days) days apart" : "Same day")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func photo(for scan: FaceScan, label: String) -> some View {
        VStack(spacing: 6) {
            if let data = scan.textureImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 190)
                    .overlay(
                        Label("No photo", systemImage: "camera")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
            Text(label).font(.caption.bold())
            Text(scan.date, format: .dateTime.day().month())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreCard(before: FaceScan, after: FaceScan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Face Score", subtitle: "Muscle measurements from TrueDepth")
            deltaRow("Overall", before.overallScore, after.overallScore)
            ForEach(FacePillar.allCases) { pillar in
                if let old = before.breakdown.value(for: pillar), let new = after.breakdown.value(for: pillar) {
                    deltaRow(pillar.title, old, new)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private func skinCard(before: FaceScan, after: FaceScan) -> some View {
        if let oldSkin = before.skin, let newSkin = after.skin {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Skin", subtitle: "From the scan photos")
                deltaRow("Skin score", oldSkin.overall, newSkin.overall)
                countRow("Blemishes", oldSkin.blemishCount, newSkin.blemishCount)
                countRow("Dark spots", oldSkin.darkSpotCount, newSkin.darkSpotCount)
                countRow("Fine lines", oldSkin.lineCount, newSkin.lineCount)
            }
            .card()
        }
    }

    private func regionCard(before: FaceScan, after: FaceScan) -> some View {
        let oldScores = RegionScorer.scores(for: before)
        let newScores = RegionScorer.scores(for: after)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "By area")
            ForEach(newScores) { item in
                if let new = item.score,
                   let old = oldScores.first(where: { $0.region == item.region })?.score {
                    deltaRow(item.region.title, old, new)
                }
            }
        }
        .card()
    }

    // MARK: - Rows

    private func deltaRow(_ title: String, _ old: Double, _ new: Double) -> some View {
        let change = new - old
        return HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text("\(Int(old.rounded()))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(new.rounded()))")
                .font(.subheadline.bold().monospacedDigit())
            Text(changeLabel(Int(change.rounded())))
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(changeColour(change))
                .frame(width: 44, alignment: .trailing)
        }
    }

    /// For counts, fewer is better.
    private func countRow(_ title: String, _ old: Int, _ new: Int) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text("\(old)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
            Text("\(new)").font(.subheadline.bold().monospacedDigit())
            Text(changeLabel(new - old))
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(changeColour(Double(old - new)))
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func changeLabel(_ change: Int) -> String {
        change == 0 ? "—" : (change > 0 ? "+\(change)" : "\(change)")
    }

    private func changeColour(_ change: Double) -> Color {
        if change > 1 { return Color.green }
        if change < -1 { return Color.orange }
        return Color.secondary
    }
}
