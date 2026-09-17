import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Query(sort: \ExerciseSession.date, order: .reverse) private var sessions: [ExerciseSession]
    @Query(sort: \FaceScan.date) private var scans: [FaceScan]

    private struct ScorePoint: Identifiable {
        let id = UUID()
        let date: Date
        let metric: String
        let value: Double
    }

    private struct DayReps: Identifiable {
        let day: Date
        let reps: Int
        var id: Date { day }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    totalsRow
                    scoreChart
                    repsChart
                    categoryBreakdown
                    recentSessions
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    // MARK: - Data

    private var scorePoints: [ScorePoint] {
        scans.flatMap { scan in
            [
                ScorePoint(date: scan.date, metric: "Overall", value: scan.overallScore),
                ScorePoint(date: scan.date, metric: "Symmetry", value: scan.symmetryScore),
                ScorePoint(date: scan.date, metric: "Range", value: scan.rangeScore),
                ScorePoint(date: scan.date, metric: "Relaxation", value: scan.relaxationScore),
            ]
        }
    }

    private var last30Days: [DayReps] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var totals: [Date: Int] = [:]
        for session in sessions {
            totals[calendar.startOfDay(for: session.date), default: 0] += session.repsCompleted
        }
        return (0..<30).reversed().compactMap { offset -> DayReps? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayReps(day: day, reps: totals[day] ?? 0)
        }
    }

    // MARK: - Sections

    private var totalsRow: some View {
        HStack(spacing: 12) {
            StatTile(title: "Sessions", value: "\(sessions.count)", symbol: "checkmark.circle")
            StatTile(title: "Total reps", value: "\(sessions.reduce(0) { $0 + $1.repsCompleted })",
                     symbol: "repeat", color: Theme.secondary)
            StatTile(title: "Best streak", value: "\(bestStreak)", symbol: "flame.fill", color: Theme.warm)
        }
    }

    private var bestStreak: Int {
        let calendar = Calendar.current
        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) }).sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for day in days {
            if let previous, let expected = calendar.date(byAdding: .day, value: 1, to: previous), expected == day {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = day
        }
        return best
    }

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Face scores", subtitle: "From your 3D scans")
            if scans.count < 2 {
                Text(scans.isEmpty
                     ? "Take a face scan to start tracking your scores."
                     : "Take another scan to see your trend. Weekly scans work well.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !scans.isEmpty {
                Chart(scorePoints) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Score", point.value))
                        .foregroundStyle(by: .value("Metric", point.metric))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value("Score", point.value))
                        .foregroundStyle(by: .value("Metric", point.metric))
                }
                .chartForegroundStyleScale([
                    "Overall": Color.white,
                    "Symmetry": Theme.accent,
                    "Range": Theme.secondary,
                    "Relaxation": Theme.warm,
                ])
                .chartYScale(domain: 0...100)
                .chartLegend(position: .bottom)
                .frame(height: 220)
            }
        }
        .card()
    }

    private var repsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Activity", subtitle: "Reps per day, last 30 days")
            Chart(last30Days) { item in
                BarMark(x: .value("Day", item.day, unit: .day), y: .value("Reps", item.reps))
                    .foregroundStyle(Theme.accent.gradient)
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 160)
        }
        .card()
    }

    private struct CategoryReps: Identifiable {
        let category: ExerciseCategory
        let reps: Int
        var id: String { category.rawValue }
    }

    private var categoryBreakdown: some View {
        let totals = Dictionary(grouping: sessions, by: \.categoryRaw)
            .compactMap { key, value -> CategoryReps? in
                guard let category = ExerciseCategory(rawValue: key) else { return nil }
                return CategoryReps(category: category, reps: value.reduce(0) { $0 + $1.repsCompleted })
            }
            .sorted { $0.reps > $1.reps }
        let maximum = max(1, totals.first?.reps ?? 1)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Muscle groups", subtitle: "Where your reps went")
            if totals.isEmpty {
                Text("Complete an exercise to see your balance across face regions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(totals) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.category.symbol)
                        .foregroundStyle(item.category.color)
                        .frame(width: 24)
                    Text(item.category.title)
                        .font(.subheadline)
                        .frame(width: 140, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(item.category.color)
                            .frame(width: proxy.size.width * CGFloat(item.reps) / CGFloat(maximum))
                    }
                    .frame(height: 8)
                    Text("\(item.reps)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent sessions")
            if sessions.isEmpty {
                Text("No sessions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(sessions.prefix(15)) { session in
                HStack(spacing: 12) {
                    Image(systemName: ExerciseLibrary.exercise(id: session.exerciseID)?.symbol ?? "face.smiling")
                        .foregroundStyle(session.category?.color ?? Theme.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.exerciseName).font(.subheadline.weight(.semibold))
                        Text(session.date, format: .dateTime.weekday().day().month().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(session.repsCompleted)/\(session.repsTarget)")
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .card()
    }
}
