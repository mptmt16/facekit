import Foundation
import Observation

struct ExerciseResult: Identifiable {
    let id = UUID()
    let exercise: Exercise
    let repsCompleted: Int
    let duration: TimeInterval
    /// Mean activation while holding, as a fraction of the target (1.0 = exactly on target).
    let intensity: Double
    /// Mean left/right balance while holding, 0...1. Nil if the exercise has no paired signals.
    let symmetry: Double?
}

/// Turns a stream of face samples into countdown → hold → rep → rest → finished.
@Observable
final class ExerciseEngine {
    enum Phase: Equatable {
        case getReady, active, rest, finished
    }

    enum Event {
        case started(cue: String)
        case holdStarted
        case holdBroken
        case nextPose(cue: String)
        case repCompleted(Int)
        case nextRep(cue: String)
        case finished
    }

    static let getReadySeconds: TimeInterval = 4
    /// Once a hold has started, allow small dips before it counts as broken.
    static let holdTolerance = 0.85

    let exercise: Exercise
    let difficulty: Double

    private(set) var phase: Phase = .getReady
    private(set) var poseIndex = 0
    private(set) var repsCompleted = 0
    /// Current pose activation relative to its target (1.0 = target reached).
    private(set) var progress: Double = 0
    /// Fraction of the hold time completed.
    private(set) var holdProgress: Double = 0
    private(set) var isHolding = false
    private(set) var symmetry: Double?
    private(set) var countdown = Int(ExerciseEngine.getReadySeconds)
    private(set) var restRemaining: TimeInterval = 0
    private(set) var faceVisible = true
    private(set) var elapsed: TimeInterval = 0

    @ObservationIgnored var onEvent: ((Event) -> Void)?

    @ObservationIgnored private var startTime: TimeInterval?
    @ObservationIgnored private var phaseStart: TimeInterval = 0
    @ObservationIgnored private var holdStart: TimeInterval?
    @ObservationIgnored private var baseline = HeadPose.zero
    @ObservationIgnored private var baselineSamples: [HeadPose] = []
    @ObservationIgnored private var intensitySum = 0.0
    @ObservationIgnored private var intensityCount = 0
    @ObservationIgnored private var symmetrySum = 0.0
    @ObservationIgnored private var symmetryCount = 0

    init(exercise: Exercise, difficulty: Double) {
        self.exercise = exercise
        self.difficulty = difficulty
    }

    var currentPose: Pose { exercise.poses[poseIndex] }

    var result: ExerciseResult {
        ExerciseResult(
            exercise: exercise,
            repsCompleted: repsCompleted,
            duration: elapsed,
            intensity: intensityCount > 0 ? intensitySum / Double(intensityCount) : 0,
            symmetry: symmetryCount > 0 ? symmetrySum / Double(symmetryCount) : nil
        )
    }

    func handle(_ sample: FaceSample) {
        let now = sample.timestamp
        if startTime == nil {
            startTime = now
            phaseStart = now
        }
        elapsed = now - (startTime ?? now)
        faceVisible = sample.isTracked

        switch phase {
        case .getReady:
            updateGetReady(sample, now: now)
        case .active:
            updateActive(sample, now: now)
        case .rest:
            updateRest(sample, now: now)
        case .finished:
            break
        }
    }

    // MARK: - Phases

    private func updateGetReady(_ sample: FaceSample, now: TimeInterval) {
        let remaining = Self.getReadySeconds - (now - phaseStart)
        countdown = max(1, Int(remaining.rounded(.up)))
        // Capture a neutral head position during the last moments of the countdown.
        if sample.isTracked, remaining < 1.5 {
            baselineSamples.append(sample.head)
        }
        guard remaining <= 0, sample.isTracked else { return }
        if exercise.usesHeadPose {
            baseline = HeadPose.average(baselineSamples)
        }
        enter(.active, at: now)
        onEvent?(.started(cue: currentPose.cue))
    }

    private func updateActive(_ sample: FaceSample, now: TimeInterval) {
        guard sample.isTracked else {
            progress = 0
            if isHolding { breakHold() }
            return
        }

        let pose = currentPose
        let value = pose.progress(in: sample, baseline: baseline, difficulty: difficulty)
        progress = value
        symmetry = pose.symmetry(in: sample)

        let threshold = isHolding ? Self.holdTolerance : 1.0
        guard value >= threshold else {
            if isHolding { breakHold() }
            return
        }

        if !isHolding {
            isHolding = true
            holdStart = now
            onEvent?(.holdStarted)
        }
        intensitySum += min(value, 1.5)
        intensityCount += 1
        if let symmetry {
            symmetrySum += symmetry
            symmetryCount += 1
        }

        let held = now - (holdStart ?? now)
        holdProgress = min(1, held / exercise.holdSeconds)
        if held >= exercise.holdSeconds {
            completePose(at: now)
        }
    }

    private func updateRest(_ sample: FaceSample, now: TimeInterval) {
        let restElapsed = now - phaseStart
        restRemaining = max(0, exercise.restSeconds - restElapsed)
        progress = sample.isTracked
            ? exercise.poses[0].progress(in: sample, baseline: baseline, difficulty: difficulty)
            : 0

        guard restElapsed >= exercise.restSeconds, sample.isTracked else { return }
        // Make the user actually release the muscle so every rep is a full contraction.
        if exercise.requiresRelaxBetweenReps, progress > 0.5 { return }
        enter(.active, at: now)
        onEvent?(.nextRep(cue: currentPose.cue))
    }

    private func completePose(at now: TimeInterval) {
        isHolding = false
        holdStart = nil
        holdProgress = 0

        if poseIndex + 1 < exercise.poses.count {
            poseIndex += 1
            onEvent?(.nextPose(cue: currentPose.cue))
            return
        }

        poseIndex = 0
        repsCompleted += 1
        if repsCompleted >= exercise.reps {
            enter(.finished, at: now)
            onEvent?(.finished)
        } else {
            enter(.rest, at: now)
            onEvent?(.repCompleted(repsCompleted))
        }
    }

    private func breakHold() {
        isHolding = false
        holdStart = nil
        holdProgress = 0
        onEvent?(.holdBroken)
    }

    private func enter(_ newPhase: Phase, at now: TimeInterval) {
        phase = newPhase
        phaseStart = now
        progress = 0
        if newPhase == .rest {
            restRemaining = exercise.restSeconds
        }
    }
}
