import SwiftUI
import SwiftData

struct AnalyzeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FaceScan.date, order: .reverse) private var scans: [FaceScan]
    @Query(sort: \BlinkTest.date, order: .reverse) private var blinkTests: [BlinkTest]
    @State private var scanning = false
    @State private var testingEyes = false

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
                                Text("About \(Int(ScanStep.totalDuration)) seconds · \(ScanStep.standard.count) guided steps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Face Score with level and progress since last scan", systemImage: "gauge.with.dots.needle.67percent")
                            Label("Structural symmetry from the 3D face mesh", systemImage: "cube.transparent")
                            Label("Left/right balance and range of 7 expressions", systemImage: "circle.lefthalf.filled")
                            Label("Muscle control with a wink test", systemImage: "scope")
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

                    Button {
                        testingEyes = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Eye Comfort Test").foregroundStyle(.primary)
                                Text("Count blinks while you read for one minute").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "eye").foregroundStyle(Theme.accent)
                        }
                    }
                }

                if !blinkTests.isEmpty {
                    Section("Eye comfort tests") {
                        ForEach(blinkTests.prefix(10)) { test in
                            NavigationLink {
                                BlinkTestResultView(test: test)
                            } label: {
                                HStack(spacing: 14) {
                                    ScoreGauge(score: test.score, title: "", size: 44, lineWidth: 5)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(test.date, format: .dateTime.day().month().year())
                                            .font(.headline)
                                        Text("\(Int(test.blinksPerMinute.rounded())) blinks/min · \(Int((test.partialRatio * 100).rounded()))% incomplete")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
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
            .fullScreenCover(isPresented: $testingEyes) {
                BlinkTestView()
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
                Text("\(scan.level.title) · Symmetry \(Int(scan.symmetryScore)) · Mobility \(Int(scan.rangeScore))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
