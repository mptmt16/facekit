import ARKit
import SwiftUI

/// Live view of everything the TrueDepth camera measures: all 52 blend shapes,
/// head angles, eye distance and left/right balance.
struct FaceLabView: View {
    @State private var tracker = FaceTracker()
    @State private var sortByActivity = false
    @AppStorage(SettingsKey.showMesh) private var showMesh = true

    var body: some View {
        VStack(spacing: 0) {
            FaceCameraView(tracker: tracker, showMesh: showMesh)
                .frame(height: 280)
                .clipped()
                .overlay(alignment: .bottom) {
                    LiveHeadReadout(tracker: tracker)
                        .padding(10)
                }

            LiveShapeList(tracker: tracker, sortByActivity: sortByActivity)
        }
        .navigationTitle("Face Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Sort by activity", isOn: $sortByActivity)
                    Toggle("Show 3D mesh", isOn: $showMesh)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            tracker.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            tracker.stop()
        }
    }
}

private struct LiveHeadReadout: View {
    let tracker: FaceTracker

    var body: some View {
        let sample = tracker.sample
        HStack(spacing: 14) {
            readout("Yaw", String(format: "%+.0f°", sample.head.yaw))
            readout("Pitch", String(format: "%+.0f°", sample.head.pitch))
            readout("Roll", String(format: "%+.0f°", sample.head.roll))
            readout("Eyes", sample.isTracked ? String(format: "%.1f mm", sample.eyeDistanceMM) : "—")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(sample.isTracked ? 1 : 0.5)
    }

    private func readout(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold().monospacedDigit())
        }
    }
}

private struct LiveShapeList: View {
    let tracker: FaceTracker
    let sortByActivity: Bool

    var body: some View {
        let sample = tracker.sample
        List {
            Section("Live balance") {
                balanceRow("Smile", sample, .mouthSmileLeft, .mouthSmileRight)
                balanceRow("Brows", sample, .browOuterUpLeft, .browOuterUpRight)
                balanceRow("Eyes closed", sample, .eyeBlinkLeft, .eyeBlinkRight)
                balanceRow("Nose scrunch", sample, .noseSneerLeft, .noseSneerRight)
            }

            if sortByActivity {
                Section("Most active") {
                    let entries = BlendShapeCatalog.groups
                        .flatMap(\.entries)
                        .sorted { sample.value($0.shape) > sample.value($1.shape) }
                    ForEach(entries) { entry in
                        shapeRow(entry, value: sample.value(entry.shape))
                    }
                }
            } else {
                ForEach(BlendShapeCatalog.groups) { group in
                    Section(group.title) {
                        ForEach(group.entries) { entry in
                            shapeRow(entry, value: sample.value(entry.shape))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func balanceRow(_ title: String, _ sample: FaceSample, _ left: BlendShape, _ right: BlendShape) -> some View {
        let l = sample.value(left)
        let r = sample.value(right)
        let symmetry = Symmetry.score(left: l, right: r)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(symmetry.map { "\(Int($0 * 100))% balanced" } ?? "relaxed")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(symmetry.map { Theme.color(forScore: $0 * 100) } ?? .secondary)
            }
            SymmetryBar(left: l, right: r)
        }
    }

    private func shapeRow(_ entry: BlendShapeCatalog.Entry, value: Double) -> some View {
        HStack(spacing: 10) {
            Text(entry.name)
                .font(.subheadline)
                .frame(width: 130, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(value > 0.5 ? Theme.accent : Theme.secondary)
                        .frame(width: proxy.size.width * min(1, max(0, value)))
                }
            }
            .frame(height: 8)
            Text("\(Int(value * 100))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}
