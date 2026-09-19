import SwiftUI
import SwiftData

struct ScanResultView: View {
    let scan: FaceScan

    @Query(sort: \FaceScan.date, order: .reverse) private var allScans: [FaceScan]
    @State private var meshMode: MeshMode = .color

    private var previousScan: FaceScan? {
        allScans.first { $0.date < scan.date }
    }

    var body: some View {
        let expressions = scan.expressions
        let tension = scan.tension
        let controls = scan.controls
        let mesh = scan.mesh
        let regionScores = RegionScorer.scores(for: scan)
        let skin = scan.skin
        let shapeReport = mesh.flatMap { FaceShapeAnalyzer.report(for: $0) }

        ScrollView {
            VStack(spacing: 20) {
                Text(scan.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                FaceScoreCard(breakdown: scan.breakdown, previous: previousScan?.breakdown, date: scan.date)
                if let skin {
                    SkinScoreCard(report: skin)
                }
                RegionScoresCard(scores: regionScores)
                ImprovementPlanCard(scores: regionScores)
                if let skin {
                    SkinZonesCard(report: skin)
                    SkinTipsCard(report: skin)
                }
                FaceShapeCard(report: shapeReport)
                meshCard(mesh)
                expressionsCard(expressions)
                controlCard(controls)
                tensionCard(tension)
                measurementsCard
                Text("FaceFit scores are for tracking your own progress over time and are not a medical assessment.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .navigationTitle("Scan results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Control

    @ViewBuilder
    private func controlCard(_ controls: [ControlResult]) -> some View {
        if !controls.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Muscle control", subtitle: "Closing one eye while the other stays open")
                ForEach(controls) { control in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(control.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int((control.score * 100).rounded()))%")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Theme.color(forScore: control.score * 100))
                        }
                        Text("Closed \(Int(control.closed * 100))% · other eye \(Int(control.open * 100))% closed")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        ProgressView(value: control.score)
                            .tint(FacePillar.control.color)
                    }
                }
            }
            .card()
        }
    }

    // MARK: - Mesh

    enum MeshMode: String, CaseIterable, Identifiable {
        case color = "Color 3D"
        case symmetry = "Symmetry map"

        var id: String { rawValue }
    }

    @ViewBuilder
    private func meshCard(_ mesh: MeshSnapshot?) -> some View {
        let texture = scan.texture
        let photo = scan.textureImageData.flatMap { UIImage(data: $0) }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "3D face", subtitle: "Drag to rotate · pinch to zoom the color model")
            Picker("3D view", selection: $meshMode) {
                ForEach(MeshMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch meshMode {
            case .color:
                if let texture, let photo {
                    TexturedFaceView(texture: texture, image: photo)
                        .frame(height: 340)
                    Text("Your real colors from the RGB camera, wrapped on the TrueDepth mesh. Stored only on this iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("No color model for this scan. Keep \"Save color 3D face\" on in Settings and scan again.",
                          systemImage: "camera")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .symmetry:
                if let mesh {
                    MeshHeatmapView(mesh: mesh)
                        .frame(height: 320)
                    HeatmapLegend()
                    if let asymmetry = scan.meshAsymmetryMM {
                        Text("Each area compared with its mirror image. Average difference: \(asymmetry, specifier: "%.1f") mm.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("The 3D map needs a TrueDepth camera. It isn't available in demo mode.", systemImage: "cube.transparent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    // MARK: - Expressions

    private func expressionsCard(_ expressions: [ExpressionResult]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Expressions", subtitle: "Peak movement and left/right balance")
            ForEach(expressions) { expression in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(expression.name, systemImage: expression.symbol)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Range \(Int(expression.rangeScore * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if let symmetry = expression.symmetry {
                            Text("\(Int(symmetry * 100))% balanced")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(Theme.color(forScore: symmetry * 100))
                        }
                    }
                    if let left = expression.left, let right = expression.right {
                        SymmetryBar(left: left, right: right)
                    } else {
                        ProgressView(value: expression.rangeScore)
                            .tint(Theme.accent)
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Tension

    private func tensionCard(_ tension: [TensionItem]) -> some View {
        let hotspots = tension.filter { $0.excess > 0.03 }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Resting tension", subtitle: "Muscles still working while you relaxed")
            if hotspots.isEmpty {
                Label("Your resting face is relaxed — no tension hotspots found.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            } else {
                ForEach(hotspots) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(item.level * 100))% active")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.warm)
                        }
                        ProgressView(value: min(1, item.level))
                            .tint(Theme.warm)
                        Text(item.advice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Measurements

    private var measurementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "3D measurements", subtitle: "Measured by the TrueDepth camera")
            measurementRow("Eye distance (eyeball centres)", scan.eyeDistanceMM)
            measurementRow("Face mesh width", scan.faceWidthMM)
            measurementRow("Face mesh height", scan.faceHeightMM)
            measurementRow("Average mesh asymmetry", scan.meshAsymmetryMM, decimals: 1)
        }
        .card()
    }

    private func measurementRow(_ title: String, _ value: Double?, decimals: Int = 0) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value.map { String(format: "%.\(decimals)f mm", $0) } ?? "—")
                .font(.subheadline.bold().monospacedDigit())
        }
    }

}
