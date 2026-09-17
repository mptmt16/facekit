import ARKit
import Foundation
import Observation

/// One expression the player has to copy in Face Challenge.
struct ChallengePrompt: Identifiable, Equatable {
    let id: String
    let emoji: String
    let title: String
    let pose: Pose

    private init(_ id: String, _ emoji: String, _ title: String, _ requirements: [Requirement]) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.pose = Pose(cue: title, requirements: requirements)
    }

    static let all: [ChallengePrompt] = [
        ChallengePrompt("grin", "😁", "Big grin", [.atLeast(.pair(.mouthSmileLeft, .mouthSmileRight), 0.5)]),
        ChallengePrompt("surprised", "😮", "Surprised!", [.atLeast(.shape(.jawOpen), 0.35), .atLeast(.shape(.browInnerUp), 0.35)]),
        ChallengePrompt("kiss", "😗", "Kiss", [.atLeast(.shape(.mouthPucker), 0.5)]),
        ChallengePrompt("wink-left", "😉", "Wink your left eye", [.atLeast(.shape(.eyeBlinkLeft), 0.6), .atMost(.shape(.eyeBlinkRight), 0.35)]),
        ChallengePrompt("wink-right", "😉", "Wink your right eye", [.atLeast(.shape(.eyeBlinkRight), 0.6), .atMost(.shape(.eyeBlinkLeft), 0.35)]),
        ChallengePrompt("puff", "🐡", "Puff your cheeks", [.atLeast(.shape(.cheekPuff), 0.3)]),
        ChallengePrompt("tongue", "😛", "Tongue out", [.atLeast(.shape(.tongueOut), 0.3)]),
        ChallengePrompt("brows", "🤨", "Eyebrows up", [.atLeast(.pair(.browOuterUpLeft, .browOuterUpRight), 0.4)]),
        ChallengePrompt("angry", "😠", "Angry frown", [.atLeast(.pair(.browDownLeft, .browDownRight), 0.35)]),
        ChallengePrompt("eyes-shut", "😑", "Eyes shut", [.atLeast(.pair(.eyeBlinkLeft, .eyeBlinkRight), 0.7)]),
        ChallengePrompt("nose", "😤", "Scrunch your nose", [.atLeast(.pair(.noseSneerLeft, .noseSneerRight), 0.3)]),
        ChallengePrompt("mouth-left", "👈", "Mouth to the left", [.atLeast(.shape(.mouthLeft), 0.4)]),
        ChallengePrompt("mouth-right", "👉", "Mouth to the right", [.atLeast(.shape(.mouthRight), 0.4)]),
        ChallengePrompt("open-wide", "😱", "Open wide", [.atLeast(.shape(.jawOpen), 0.55)]),
        ChallengePrompt("turn-left", "⬅️", "Turn your head left", [.atLeast(.yaw, 22)]),
        ChallengePrompt("turn-right", "➡️", "Turn your head right", [.atLeast(.yaw, -22)]),
    ]
}

/// 60-second expression-matching game: match fast, keep a streak, score points.
@Observable
final class ChallengeEngine {
    enum Phase: Equatable { case ready, countdown, playing, finished }

    enum Event {
        case started(ChallengePrompt)
        case matched(points: Int, next: ChallengePrompt)
        case missed(next: ChallengePrompt)
        case finished(score: Int)
    }

    static let roundSeconds: TimeInterval = 60
    static let promptSeconds: TimeInterval = 6
    static let matchHoldSeconds: TimeInterval = 0.45
    static let countdownSeconds: TimeInterval = 3

    private(set) var phase: Phase = .ready
    private(set) var countdown = 3
    private(set) var timeRemaining: TimeInterval = ChallengeEngine.roundSeconds
    private(set) var promptRemaining: TimeInterval = ChallengeEngine.promptSeconds
    private(set) var prompt: ChallengePrompt
    private(set) var progress: Double = 0
    private(set) var score = 0
    private(set) var matches = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var fastestMatch: TimeInterval?
    private(set) var lastPoints = 0
    /// Increments on every award so the view can animate "+points".
    private(set) var awardCount = 0
    private(set) var faceVisible = true

    @ObservationIgnored var onEvent: ((Event) -> Void)?

    @ObservationIgnored private var phaseStart: TimeInterval?
    @ObservationIgnored private var promptStart: TimeInterval = 0
    @ObservationIgnored private var holdStart: TimeInterval?

    init() {
        prompt = ChallengePrompt.all[0]
    }

    func start() {
        score = 0
        matches = 0
        streak = 0
        bestStreak = 0
        fastestMatch = nil
        lastPoints = 0
        progress = 0
        countdown = Int(Self.countdownSeconds)
        timeRemaining = Self.roundSeconds
        promptRemaining = Self.promptSeconds
        holdStart = nil
        phaseStart = nil
        prompt = nextPrompt(after: nil)
        phase = .countdown
    }

    func handle(_ sample: FaceSample) {
        if faceVisible != sample.isTracked {
            faceVisible = sample.isTracked
        }
        let now = sample.timestamp

        switch phase {
        case .ready, .finished:
            return

        case .countdown:
            if phaseStart == nil { phaseStart = now }
            let remaining = Self.countdownSeconds - (now - (phaseStart ?? now))
            let shown = max(1, Int(remaining.rounded(.up)))
            if shown != countdown { countdown = shown }
            if remaining <= 0 {
                phase = .playing
                phaseStart = now
                promptStart = now
                onEvent?(.started(prompt))
            }

        case .playing:
            timeRemaining = max(0, Self.roundSeconds - (now - (phaseStart ?? now)))
            if timeRemaining <= 0 {
                phase = .finished
                progress = 0
                onEvent?(.finished(score: score))
                return
            }
            promptRemaining = max(0, Self.promptSeconds - (now - promptStart))

            guard sample.isTracked else {
                progress = 0
                holdStart = nil
                return
            }

            progress = prompt.pose.progress(in: sample, baseline: .zero, difficulty: 1)
            let threshold = holdStart == nil ? 1.0 : 0.85
            if progress >= threshold {
                if holdStart == nil { holdStart = now }
                let heldSince = holdStart ?? now
                if now - heldSince >= Self.matchHoldSeconds {
                    award(reaction: heldSince - promptStart, now: now)
                }
            } else {
                holdStart = nil
                if promptRemaining <= 0 {
                    streak = 0
                    advancePrompt(now: now)
                    onEvent?(.missed(next: prompt))
                }
            }
        }
    }

    private func award(reaction: TimeInterval, now: TimeInterval) {
        streak += 1
        bestStreak = max(bestStreak, streak)
        let speedBonus = max(0, Int((100 - reaction * 25).rounded()))
        let streakBonus = min(50, (streak - 1) * 10)
        let points = 100 + speedBonus + streakBonus
        score += points
        matches += 1
        lastPoints = points
        awardCount += 1
        fastestMatch = min(fastestMatch ?? reaction, reaction)
        advancePrompt(now: now)
        onEvent?(.matched(points: points, next: prompt))
    }

    private func advancePrompt(now: TimeInterval) {
        prompt = nextPrompt(after: prompt)
        promptStart = now
        holdStart = nil
        progress = 0
        promptRemaining = Self.promptSeconds
    }

    private func nextPrompt(after current: ChallengePrompt?) -> ChallengePrompt {
        let options = ChallengePrompt.all.filter { $0.id != current?.id }
        return options.randomElement() ?? ChallengePrompt.all[0]
    }
}
