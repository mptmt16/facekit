import SwiftUI

struct ScanResultView: View {
    let scan: FaceScan

    var body: some View {
        let expressions = scan.expressions
        let tension = scan.tension
        let mesh = scan.mesh

        ScrollView {
            VStack(spacing: 20) {
                overviewCard
                meshCard(mesh)
                expressionsCard(expressions)
                tensionCard(tension)
                measurementsCard
                recommendationsCard
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

    // MARK: - Overview

    private var overviewCard: some View {
        VStack(spacing: 18) {
            Text(scan.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScoreGauge(score: scan.overallScore, title: "Face score", size: 130, lineWidth: 14)
            HStack(alignment: .top) {
                ScoreGauge(score: scan.symmetryScore, title: "Symmetry")
                    .frame(maxWidth: .infinity)
                ScoreGauge(score: scan.rangeScore, title: "Expression\nrange")
                    .frame(maxWidth: .infinity)
                ScoreGauge(score: scan.relaxationScore, title: "Relaxation")
                    .frame(maxWidth: .infinity)
            }
            Text(summary)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .card()
    }

    private var summary: String {
        let parts = [("symmetry", scan.symmetryScore), ("expression range", scan.rangeScore), ("relaxation", scan.relaxationScore)]
        guard let best = parts.max(by: { $0.1 < $1.1 }), let worst = parts.min(by: { $0.1 < $1.1 }) else { return "" }
        if worst.1 >= 80 {
            return "Excellent all round. Keep training to maintain your results."
        }
        return "Your strongest area is \(best.0). Focus on \(worst.0) next — the exercises below target it."
    }

    // MARK: - Mesh

    @ViewBuilder
    private func meshCard(_ mesh: MeshSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "3D symmetry map", subtitle: "Each area compared with its mirror image")
            if let mesh {
                MeshHeatmapView(mesh: mesh)
                    .frame(height: 320)
                HeatmapLegend()
                if let asymmetry = scan.meshAsymmetryMM {
                    Text("Average difference: \(asymmetry, specifier: "%.1f") mm · drag to rotate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("The 3D map needs a TrueDepth camera. It isn't available in demo mode.", systemImage: "cube.transparent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

    // MARK: - Recommendations

    private var recommendations: [Exercise] {
        var seen = Set<String>()
        let findings = scan.focusAreas.prefix(3)
        let candidates = findings.isEmpty ? ["smile", "brows"] : Array(findings)
        return candidates
            .flatMap { ExerciseLibrary.recommended(forFinding: $0) }
            .filter { seen.insert($0.id).inserted }
            .prefix(4)
            .map { $0 }
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recommended for you", subtitle: "Based on your weakest areas")
            ForEach(recommendations) { exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    HStack {
                        ExerciseRow(exercise: exercise)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}
