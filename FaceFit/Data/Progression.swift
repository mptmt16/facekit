import Foundation

/// XP, levels, unlocks and mastery. Everything is derived from saved history,
/// so there is no separate score to keep in sync.
enum Progression {
    static let dailyGoalXP = 150

    // MARK: - Earning

    static func xp(reps: Int, target: Int, intensity: Double) -> Int {
        var earned = reps * 5
        if reps >= target, target > 0 { earned += 20 }
        if intensity >= 1 { earned += 10 }
        return earned
    }

    static func xp(for session: ExerciseSession) -> Int {
        xp(reps: session.repsCompleted, target: session.repsTarget, intensity: session.intensity)
    }

    static func xp(for scan: FaceScan) -> Int { 80 }

    static func xp(for test: BlinkTest) -> Int { 40 }

    static func totalXP(sessions: [ExerciseSession], scans: [FaceScan], blinkTests: [BlinkTest],
                        challengeGames: Int, challengeHighScore: Int) -> Int {
        var total = sessions.reduce(0) { $0 + xp(for: $1) }
        total += scans.reduce(0) { $0 + xp(for: $1) }
        total += blinkTests.reduce(0) { $0 + xp(for: $1) }
        total += challengeGames * 25 + challengeHighScore / 20
        return total
    }

    static func xpEarned(on day: Date, sessions: [ExerciseSession], scans: [FaceScan], blinkTests: [BlinkTest]) -> Int {
        let calendar = Calendar.current
        var total = sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + xp(for: $1) }
        total += scans.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + xp(for: $1) }
        total += blinkTests.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + xp(for: $1) }
        return total
    }

    // MARK: - Levels

    /// Total XP needed to reach a level. Level 1 starts at zero.
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let value = 150 * pow(Double(level - 1), 1.5)
        return Int((value / 10).rounded()) * 10
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while level < 60, xp >= xpRequired(forLevel: level + 1) {
            level += 1
        }
        return level
    }

    struct LevelProgress {
        var level: Int
        var xp: Int
        var levelStart: Int
        var levelEnd: Int

        var intoLevel: Int { xp - levelStart }
        var span: Int { Swift.max(1, levelEnd - levelStart) }
        var fraction: Double { Swift.min(1, Double(intoLevel) / Double(span)) }
        var remaining: Int { Swift.max(0, levelEnd - xp) }
    }

    static func progress(forXP xp: Int) -> LevelProgress {
        let level = level(forXP: xp)
        return LevelProgress(level: level,
                             xp: xp,
                             levelStart: xpRequired(forLevel: level),
                             levelEnd: xpRequired(forLevel: level + 1))
    }

    /// A friendly rank name shown next to the level.
    static func rank(forLevel level: Int) -> String {
        switch level {
        case ..<3: "Rookie"
        case 3..<5: "Trainee"
        case 5..<8: "Regular"
        case 8..<12: "Athlete"
        case 12..<18: "Pro"
        default: "Master"
        }
    }

    // MARK: - Unlocks

    /// Which player level unlocks each exercise. Everything else is locked until then.
    static let unlockLevels: [String: Int] = [
        "smile-lift": 1, "brow-raise": 1, "jaw-opener": 1, "soft-face": 1,
        "cheek-puff": 2, "fish-face": 2,
        "neck-turn": 3, "nose-scrunch": 3,
        "kiss-smile": 4, "eye-squeeze": 4,
        "side-smile": 5, "chin-lift": 5,
        "jaw-slide": 6, "wide-eyes": 6,
        "lip-roll": 7, "head-tilt": 7,
        "wink-control": 8,
        "lion-stretch": 9,
    ]

    static func unlockLevel(for exerciseID: String) -> Int {
        unlockLevels[exerciseID] ?? 1
    }

    static func isUnlocked(_ exercise: Exercise, playerLevel: Int) -> Bool {
        playerLevel >= unlockLevel(for: exercise.id)
    }

    static func unlocked(playerLevel: Int) -> [Exercise] {
        ExerciseLibrary.all.filter { isUnlocked($0, playerLevel: playerLevel) }
    }

    /// Exercises that become available when the player reaches this level.
    static func unlocks(atLevel level: Int) -> [Exercise] {
        ExerciseLibrary.all.filter { unlockLevel(for: $0.id) == level }
    }

    static let programUnlockLevels: [String: Int] = [
        "stress-release": 2, "jawline": 3, "smile-symmetry": 4, "bright-eyes": 5, "full-face": 7,
    ]

    static func unlockLevel(forProgram programID: String) -> Int {
        programUnlockLevels[programID] ?? 1
    }

    // MARK: - Mastery

    enum Mastery: Int {
        case none = 0, bronze = 1, silver = 2, gold = 3

        var repsNeeded: Int {
            switch self {
            case .none: 0
            case .bronze: 20
            case .silver: 60
            case .gold: 150
            }
        }

        var title: String {
            switch self {
            case .none: "Not started"
            case .bronze: "Bronze"
            case .silver: "Silver"
            case .gold: "Gold"
            }
        }
    }

    static func reps(for exerciseID: String, in sessions: [ExerciseSession]) -> Int {
        sessions.filter { $0.exerciseID == exerciseID }.reduce(0) { $0 + $1.repsCompleted }
    }

    static func mastery(reps: Int) -> Mastery {
        if reps >= Mastery.gold.repsNeeded { return .gold }
        if reps >= Mastery.silver.repsNeeded { return .silver }
        if reps >= Mastery.bronze.repsNeeded { return .bronze }
        return .none
    }

    /// Reps still needed for the next star, or nil at gold.
    static func repsToNextStar(reps: Int) -> Int? {
        for step in [Mastery.bronze, .silver, .gold] where reps < step.repsNeeded {
            return step.repsNeeded - reps
        }
        return nil
    }
}
