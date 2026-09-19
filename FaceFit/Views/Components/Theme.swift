import SwiftUI

enum Theme {
    static let accent = Color(red: 0.30, green: 0.85, blue: 0.78)
    static let secondary = Color(red: 0.55, green: 0.55, blue: 1.00)
    static let warm = Color(red: 1.00, green: 0.62, blue: 0.40)
    static let card = Color(white: 0.11)

    static func color(forScore score: Double) -> Color {
        switch score {
        case 80...: Color(red: 0.35, green: 0.85, blue: 0.55)
        case 60..<80: accent
        case 40..<60: Color(red: 1.00, green: 0.78, blue: 0.35)
        default: Color(red: 1.00, green: 0.45, blue: 0.45)
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var color: Color = Theme.accent
    var trackOpacity: Double = 0.15

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeOut(duration: 0.15), value: progress)
    }
}

/// Circular 0–100 score with a label underneath.
struct ScoreGauge: View {
    var score: Double
    var title: String
    var size: CGFloat = 72
    var lineWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ProgressRing(progress: score / 100, lineWidth: lineWidth, color: Theme.color(forScore: score))
                Text("\(Int(score.rounded()))")
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: size, height: size)
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var symbol: String
    var color: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Two bars growing from the centre: left side vs right side.
struct SymmetryBar: View {
    var left: Double
    var right: Double
    var color: Color = Theme.accent

    var body: some View {
        HStack(spacing: 8) {
            Text("L").font(.caption2.bold()).foregroundStyle(.secondary)
            GeometryReader { proxy in
                let half = proxy.size.width / 2
                ZStack {
                    Capsule().fill(Color.white.opacity(0.08))
                    HStack(spacing: 2) {
                        ZStack(alignment: .trailing) {
                            Color.clear
                            Capsule().fill(color).frame(width: half * min(1, max(0, left)))
                        }
                        ZStack(alignment: .leading) {
                            Color.clear
                            Capsule().fill(color.opacity(0.75)).frame(width: half * min(1, max(0, right)))
                        }
                    }
                }
            }
            .frame(height: 8)
            Text("R").font(.caption2.bold()).foregroundStyle(.secondary)
        }
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold())
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct LevelBadge: View {
    let level: ExerciseLevel

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index < level.bars ? level.color : Color.white.opacity(0.18))
                    .frame(width: 3, height: 5 + CGFloat(index) * 3)
            }
            Text(level.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(level.color)
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    var isFavourite = false
    var mastery: Progression.Mastery = .none
    var isLocked = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isLocked ? "lock.fill" : exercise.symbol)
                .font(.title3)
                .foregroundStyle(isLocked ? Color.secondary : exercise.category.color)
                .frame(width: 44, height: 44)
                .background((isLocked ? Color.white : exercise.category.color).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(isLocked ? Color.secondary : Color.primary)
                if isLocked {
                    Text("Unlocks at level \(Progression.unlockLevel(for: exercise.id))")
                        .font(.caption)
                        .foregroundStyle(Theme.warm)
                } else {
                    Text("\(exercise.reps) reps · \(exercise.holdSeconds.formatted())s hold · \(exercise.estimatedDuration.clockString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    LevelBadge(level: exercise.level)
                    if !isLocked, mastery != .none {
                        MasteryStars(mastery: mastery, compact: true)
                    }
                }
            }
            Spacer(minLength: 0)
            if isFavourite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warm)
            }
        }
    }
}
