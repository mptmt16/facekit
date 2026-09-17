import SwiftUI
import SwiftData

struct AnalyzeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FaceScan.date, order: .reverse) private var scans: [FaceScan]
    @State private var scanning = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            Image(systemName: "faceid")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("3D Face Scan").font(.title3.bold())
                                Text("About \(Int(ScanStep.totalDuration)) seconds · 8 guided steps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Structural symmetry from the 3D face mesh", systemImage: "cube.transparent")
                            Label("Left/right balance of 7 expressions", systemImage: "circle.lefthalf.filled")
                            Label("Expression range of each muscle group", systemImage: "arrow.up.left.and.arrow.down.right")
                            Label("Hidden tension in your resting face", systemImage: "waveform.path.ecg")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Button("Start scan") { scanning = true }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    NavigationLink {
                        FaceLabView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Face Lab")
                                Text("See all 52 muscle signals live").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "waveform").foregroundStyle(Theme.secondary)
                        }
                    }
                }

                Section("Past scans") {
                    if scans.isEmpty {
                        Text("No scans yet. Your first scan becomes the baseline for tracking progress.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(scans) { scan in
                        NavigationLink {
                            ScanResultView(scan: scan)
                        } label: {
                            ScanRow(scan: scan)
                        }
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            modelContext.delete(scans[offset])
                        }
                    }
                }
            }
            .navigationTitle("Analyze")
            .fullScreenCover(isPresented: $scanning) {
                FaceScanView()
            }
        }
    }
}

struct ScanRow: View {
    let scan: FaceScan

    var body: some View {
        HStack(spacing: 14) {
            ScoreGauge(score: scan.overallScore, title: "", size: 44, lineWidth: 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(scan.date, format: .dateTime.day().month().year())
                    .font(.headline)
                Text("Symmetry \(Int(scan.symmetryScore)) · Range \(Int(scan.rangeScore)) · Relaxed \(Int(scan.relaxationScore))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
