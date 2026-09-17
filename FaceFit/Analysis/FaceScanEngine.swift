import ARKit
import Foundation
import Observation
import simd

/// Runs the guided face scan and computes symmetry, expression range, resting tension
/// and 3D measurements from TrueDepth data.
@Observable
final class FaceScanEngine {
    enum State: Equatable { case intro, running, finished }

    static let leadInSeconds: TimeInterval = 1.5

    let steps: [ScanStep]

    private(set) var state: State = .intro
    private(set) var stepIndex = 0
    /// True during the short "get ready" gap before each step starts recording.
    private(set) var isLeadIn = true
    private(set) var stepProgress: Double = 0
    private(set) var faceVisible = true

    @ObservationIgnored var onStepStarted: ((ScanStep) -> Void)?
    @ObservationIgnored var onRecordingStarted: ((ScanStep) -> Void)?
    @ObservationIgnored var onFinished: ((ScanOutcome) -> Void)?

    @ObservationIgnored private var lastTimestamp: TimeInterval?
    @ObservationIgnored private var leadInRemaining: TimeInterval = 0
    @ObservationIgnored private var recordedTime: TimeInterval = 0

    // Neutral step accumulators
    @ObservationIgnored private var vertexSum: [SIMD3<Float>] = []
    @ObservationIgnored private var vertexFrames = 0
    @ObservationIgnored private var triangleIndices: [Int16] = []
    @ObservationIgnored private var tensionSums: [String: Double] = [:]
    @ObservationIgnored private var neutralFrames = 0
    @ObservationIgnored private var eyeDistanceSum = 0.0

    // Expression step accumulators: smoothed value and peak per blend shape
    @ObservationIgnored private var smoothed: [BlendShape: Double] = [:]
    @ObservationIgnored private var peaks: [BlendShape: Double] = [:]
    @ObservationIgnored private var expressions: [ExpressionResult] = []

    init(steps: [ScanStep] = ScanStep.standard) {
        self.steps = steps
    }

    var currentStep: ScanStep { steps[min(stepIndex, steps.count - 1)] }

    var overallProgress: Double {
        guard !steps.isEmpty else { return 0 }
        return min(1, (Double(stepIndex) + stepProgress) / Double(steps.count))
    }

    func begin() {
        state = .running
        stepIndex = 0
        expressions = []
        startStep()
    }

    func handle(_ sample: FaceSample) {
        faceVisible = sample.isTracked
        guard state == .running else { return }
        let dt = lastTimestamp.map { min(0.1, max(0, sample.timestamp - $0)) } ?? 0
        lastTimestamp = sample.timestamp
        // The clock only runs while a face is visible, so nothing is recorded from an empty frame.
        guard sample.isTracked else { return }

        if leadInRemaining > 0 {
            leadInRemaining -= dt
            if leadInRemaining <= 0 {
                isLeadIn = false
                onRecordingStarted?(currentStep)
            }
            return
        }

        recordedTime += dt
        stepProgress = min(1, recordedTime / currentStep.duration)
        record(sample, for: currentStep)

        if recordedTime >= currentStep.duration {
            finishStep()
        }
    }

    // MARK: - Steps

    private func startStep() {
        leadInRemaining = Self.leadInSeconds
        recordedTime = 0
        stepProgress = 0
        isLeadIn = true
        smoothed = [:]
        peaks = [:]
        onStepStarted?(currentStep)
    }

    private func finishStep() {
        let step = currentStep
        if case let .expression(left, right, others, reference) = step.kind {
            expressions.append(makeExpressionResult(step: step, left: left, right: right, others: others, reference: reference))
        }
        if stepIndex + 1 < steps.count {
            stepIndex += 1
            startStep()
        } else {
            state = .finished
            stepProgress = 1
            onFinished?(computeOutcome())
        }
    }

    private func record(_ sample: FaceSample, for step: ScanStep) {
        switch step.kind {
        case .neutral:
            recordNeutral(sample)
        case let .expression(left, right, others, _):
            let shapes = [left, right].compactMap { $0 } + others
            for shape in shapes {
                // Light smoothing so a single noisy frame cannot set the peak.
                let value = 0.6 * (smoothed[shape] ?? sample.value(shape)) + 0.4 * sample.value(shape)
                smoothed[shape] = value
                peaks[shape] = max(peaks[shape] ?? 0, value)
            }
        }
    }

    private func recordNeutral(_ sample: FaceSample) {
        neutralFrames += 1
        eyeDistanceSum += sample.eyeDistanceMM
        for check in TensionCheck.all {
            let level = check.shapes.map { sample.value($0) }.reduce(0, +) / Double(check.shapes.count)
            tensionSums[check.id, default: 0] += level
        }

        // Skip blinks so closed eyelids do not distort the averaged mesh.
        let blink = max(sample.value(.eyeBlinkLeft), sample.value(.eyeBlinkRight))
        guard !sample.vertices.isEmpty, blink < 0.4 else { return }
        if vertexSum.count != sample.vertices.count {
            vertexSum = [SIMD3<Float>](repeating: .zero, count: sample.vertices.count)
            vertexFrames = 0
        }
        for i in sample.vertices.indices {
            vertexSum[i] += sample.vertices[i]
        }
        vertexFrames += 1
        if triangleIndices.isEmpty {
            triangleIndices = sample.triangleIndices
        }
    }

    private func makeExpressionResult(step: ScanStep, left: BlendShape?, right: BlendShape?,
                                      others: [BlendShape], reference: Double) -> ExpressionResult {
        let leftPeak = left.map { peaks[$0] ?? 0 }
        let rightPeak = right.map { peaks[$0] ?? 0 }
        let allPeaks = [leftPeak, rightPeak].compactMap { $0 } + others.map { peaks[$0] ?? 0 }
        let peak = allPeaks.isEmpty ? 0 : allPeaks.reduce(0, +) / Double(allPeaks.count)

        var symmetry: Double?
        if let leftPeak, let rightPeak {
            symmetry = Symmetry.score(left: leftPeak, right: rightPeak, minimumMovement: 0.1)
        }
        return ExpressionResult(id: step.id, name: step.title, symbol: step.symbol,
                                left: leftPeak, right: rightPeak, peak: peak,
                                reference: reference, symmetry: symmetry)
    }

    // MARK: - Scoring

    private func computeOutcome() -> ScanOutcome {
        let frames = Double(max(neutralFrames, 1))

        // Resting tension
        let tension = TensionCheck.all.map { check in
            TensionItem(id: check.id, name: check.name, advice: check.advice,
                        level: (tensionSums[check.id] ?? 0) / frames, allowance: check.allowance)
        }
        let totalExcess = tension.reduce(0) { $0 + $1.excess }
        let relaxationScore = 100 * (1 - min(1, totalExcess / 0.5))

        // Expression range
        let rangeScore = expressions.isEmpty ? 0 : 100 * expressions.map(\.rangeScore).reduce(0, +) / Double(expressions.count)

        // 3D mesh: average, asymmetry and measurements
        var mesh: MeshSnapshot?
        var meshAsymmetryMM: Double?
        var faceWidthMM: Double?
        var faceHeightMM: Double?
        if vertexFrames > 0 {
            let average = vertexSum.map { $0 / Float(vertexFrames) }
            let deviation = FaceMeshMath.asymmetry(of: average)
            meshAsymmetryMM = Double(deviation.reduce(0, +) / Float(deviation.count)) * 1000
            if let bounds = FaceMeshMath.bounds(of: average) {
                faceWidthMM = Double(bounds.width) * 1000
                faceHeightMM = Double(bounds.height) * 1000
            }
            mesh = MeshSnapshot(vertices: average.flatMap { [$0.x, $0.y, $0.z] },
                                triangleIndices: triangleIndices, deviation: deviation)
        }

        // Symmetry: expression balance, blended with structural (mesh) symmetry when available.
        let symmetries = expressions.compactMap(\.symmetry)
        let expressionSymmetry = symmetries.isEmpty ? nil : 100 * symmetries.reduce(0, +) / Double(symmetries.count)
        let structuralSymmetry = meshAsymmetryMM.map { min(100, max(0, 100 - ($0 - 1.0) * 15)) }
        let symmetryScore: Double = switch (expressionSymmetry, structuralSymmetry) {
        case let (e?, s?): 0.6 * e + 0.4 * s
        case let (e?, nil): e
        case let (nil, s?): s
        case (nil, nil): 0
        }

        let overall = (symmetryScore + rangeScore + relaxationScore) / 3
        let eyeDistance: Double? = neutralFrames > 0 ? eyeDistanceSum / frames : nil

        return ScanOutcome(
            overallScore: overall,
            symmetryScore: symmetryScore,
            rangeScore: rangeScore,
            relaxationScore: relaxationScore,
            meshAsymmetryMM: meshAsymmetryMM,
            eyeDistanceMM: eyeDistance,
            faceWidthMM: faceWidthMM,
            faceHeightMM: faceHeightMM,
            expressions: expressions,
            tension: tension.sorted { $0.excess > $1.excess },
            mesh: mesh
        )
    }
}
