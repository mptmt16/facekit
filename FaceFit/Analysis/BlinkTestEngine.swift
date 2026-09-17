import ARKit
import Foundation
import Observation

/// What a 60-second blink test measured.
struct BlinkTestResult {
    var duration: TimeInterval
    var blinkCount: Int
    var partialBlinkCount: Int
    /// Longest stretch without any blink, in seconds.
    var longestGap: TimeInterval
    /// Mean eye openness between blinks, 0...1.
    var openness: Double
    /// Mean squint while reading, 0...1.
    var squint: Double

    var blinksPerMinute: Double {
        duration > 0 ? Double(blinkCount) / (duration / 60) : 0
    }

    var partialRatio: Double {
        let total = blinkCount + partialBlinkCount
        return total > 0 ? Double(partialBlinkCount) / Double(total) : 0
    }

    var score: Double {
        BlinkScoring.score(rate: blinksPerMinute, partialRatio: partialRatio, longestGap: longestGap)
    }
}

enum BlinkScoring {
    /// 0–100 eye comfort score: blink rate (50%), complete blinks (30%), longest stare (20%).
    static func score(rate: Double, partialRatio: Double, longestGap: Double) -> Double {
        let rateScore: Double
        if rate < 12 {
            rateScore = max(0, rate / 12)
        } else if rate <= 25 {
            rateScore = 1
        } else {
            rateScore = max(0.5, 1 - (rate - 25) * 0.03)
        }
        let completeness = 1 - min(1, partialRatio / 0.5)
        let gapScore = 1 - min(1, max(0, longestGap - 6) / 14)
        return 100 * (0.5 * rateScore + 0.3 * completeness + 0.2 * gapScore)
    }

    static func advice(rate: Double, partialRatio: Double, longestGap: Double, squint: Double) -> [String] {
        var tips: [String] = []
        if rate < 12 {
            tips.append("You blink less than usual while reading. Every 20 minutes, look about 6 metres (20 feet) away for 20 seconds.")
        }
        if partialRatio > 0.25 {
            tips.append("Many of your blinks don't fully close. Practise slow, complete blinks: close gently, pause for two seconds, then open.")
        }
        if longestGap > 12 {
            tips.append("You went \(Int(longestGap)) seconds without blinking. Long stares dry the eye surface, so look away from the screen now and then.")
        }
        if squint > 0.35 {
            tips.append("You squint while reading. Try a larger text size, more brightness, or holding the phone a little further away.")
        }
        if tips.isEmpty {
            tips.append("Your blinking looks healthy. Keep taking regular screen breaks.")
        }
        return tips
    }
}

/// Counts full and partial blinks from the TrueDepth eyelid signals while the user reads.
@Observable
final class BlinkTestEngine {
    enum State: Equatable { case intro, running, finished }

    static let testSeconds: TimeInterval = 60

    private(set) var state: State = .intro
    private(set) var elapsed: TimeInterval = 0
    private(set) var blinkCount = 0
    private(set) var partialCount = 0
    private(set) var faceVisible = true
    private(set) var result: BlinkTestResult?

    @ObservationIgnored var onBlink: (() -> Void)?
    @ObservationIgnored var onFinished: ((BlinkTestResult) -> Void)?

    @ObservationIgnored private var lastTimestamp: TimeInterval?
    @ObservationIgnored private var baseline = 0.1
    @ObservationIgnored private var closed = false
    @ObservationIgnored private var closeStart: TimeInterval = 0
    @ObservationIgnored private var partialCandidate = false
    @ObservationIgnored private var lastBlinkEnd: TimeInterval = 0
    @ObservationIgnored private var longestGap: TimeInterval = 0
    @ObservationIgnored private var opennessSum = 0.0
    @ObservationIgnored private var squintSum = 0.0
    @ObservationIgnored private var openFrames = 0

    var progress: Double { min(1, elapsed / Self.testSeconds) }

    func begin() {
        state = .running
        elapsed = 0
        blinkCount = 0
        partialCount = 0
        result = nil
        lastTimestamp = nil
        baseline = 0.1
        closed = false
        partialCandidate = false
        lastBlinkEnd = 0
        longestGap = 0
        opennessSum = 0
        squintSum = 0
        openFrames = 0
    }

    func handle(_ sample: FaceSample) {
        if faceVisible != sample.isTracked {
            faceVisible = sample.isTracked
        }
        guard state == .running else { return }
        let dt = lastTimestamp.map { min(0.1, max(0, sample.timestamp - $0)) } ?? 0
        lastTimestamp = sample.timestamp
        // The test clock only runs while the face is visible.
        guard sample.isTracked else { return }

        elapsed += dt
        let lid = (sample.value(.eyeBlinkLeft) + sample.value(.eyeBlinkRight)) / 2
        detectBlink(lid: lid)

        if !closed && !partialCandidate {
            // Follow the resting eyelid position so naturally narrow eyes aren't miscounted.
            baseline += (min(lid, baseline + 0.1) - baseline) * 0.02
            opennessSum += 1 - lid
            squintSum += (sample.value(.eyeSquintLeft) + sample.value(.eyeSquintRight)) / 2
            openFrames += 1
        }

        longestGap = max(longestGap, elapsed - lastBlinkEnd)
        if elapsed >= Self.testSeconds {
            finish()
        }
    }

    private func detectBlink(lid: Double) {
        let closeLevel = baseline + 0.35
        let reopenLevel = baseline + 0.15
        let partialLevel = baseline + 0.18

        if closed {
            if lid < reopenLevel {
                closed = false
                partialCandidate = false
                // Closures longer than a second are rests, not blinks.
                if elapsed - closeStart < 1.0 {
                    blinkCount += 1
                    onBlink?()
                }
                lastBlinkEnd = elapsed
            }
        } else if lid > closeLevel {
            closed = true
            closeStart = elapsed
        } else if lid > partialLevel {
            partialCandidate = true
        } else if partialCandidate, lid < baseline + 0.08 {
            partialCandidate = false
            partialCount += 1
            lastBlinkEnd = elapsed
        }
    }

    private func finish() {
        state = .finished
        let frames = Double(max(openFrames, 1))
        let outcome = BlinkTestResult(
            duration: elapsed,
            blinkCount: blinkCount,
            partialBlinkCount: partialCount,
            longestGap: longestGap,
            openness: opennessSum / frames,
            squint: squintSum / frames
        )
        result = outcome
        onFinished?(outcome)
    }
}
