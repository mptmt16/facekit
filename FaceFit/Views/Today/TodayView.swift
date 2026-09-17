import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \ExerciseSession.date, order: .reverse) private var sessions: [ExerciseSession]
    @Query(sort: \FaceScan.date, order: .reverse) private var scans: [FaceScan]
    @Query(sort: \BlinkTest.date, order: .reverse) private var blinkTests: [BlinkTest]
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0

    @State private var routineRunning = false
    @State private var scanning = false
    @State private var showingSettings = false
    @State private var playingChallenge = false
    @State private var testingEyes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    routineCard
                    statsRow
                    scanCard
                    playRow
                    weekChart
                    if !FaceTracker.isTrueDepthAvailable {
                        Label("This device has no TrueDepth camera, so FaceFit runs in demo mode with simulated data.",
                              systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .card()
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .fullScreenCover(isPresented: $routineRunning) {
                ExerciseSessionView(exercises: ExerciseLibrary.dailyRoutine)
            }
            .fullScreenCover(isPresented: $scanning) { FaceScanView() }
            .fullScreenCover(isPresented: $playingChallenge) { FaceChallengeView() }
            .fullScreenCover(isPresented: $testingEyes) { BlinkTestView() }
        }
    }

    private var playRow: some View {
        HStack(spacing: 12) {
            Button {
                playingChallenge = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🎭").font(.title)
                    Text("Face Challenge").font(.headline)
                    Text(challengeHighScore > 0 ? "Best: \(challengeHighScore)" : "60-second expression game")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                testingEyes = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "eye")
                        .font(.title)
                        .foregroundStyle(Theme.accent)
                    Text("Eye Comfort").font(.headline)
                    Text(blinkTests.first.map { "Last score: \(Int($0.score.rounded()))" } ?? "1-minute blink test")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data

    private var todaysSessions: [ExerciseSession] {
        sessions.filter { Calendar.current.isDateInToday($0.date) }
    }

    private struct DayReps: Identifiable {
        let day: Date
        let reps: Int
        var id: Date { day }
    }

    private var lastSevenDays: [DayReps] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset -> DayReps? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let reps = sessions
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.repsCompleted }
            return DayReps(day: day, reps: reps)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(todaysSessions.isEmpty ? "Ready for today's workout?" : "Nice — you trained today.")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Face Workout").font(.title3.bold())
                    Text("\(ExerciseLibrary.dailyRoutine.count) exercises · about \(ExerciseLibrary.dailyRoutineDuration.clockString) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExerciseLibrary.dailyRoutine) { exercise in
                        Label(exercise.name, systemImage: exercise.symbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(exercise.category.color.opacity(0.15), in: Capsule())
                    }
                }
            }
            Button("Start workout") { routineRunning = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(title: "Day streak", value: "\(sessions.streak)", symbol: "flame.fill", color: Theme.warm)
            StatTile(title: "Reps today", value: "\(todaysSessions.reduce(0) { $0 + $1.repsCompleted })",
                     symbol: "repeat")
            StatTile(title: "Minutes today",
                     value: "\(Int((todaysSessions.reduce(0) { $0 + $1.duration } / 60).rounded()))",
                     symbol: "timer", color: Theme.secondary)
        }
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This week", subtitle: "Reps completed per day")
            Chart(lastSevenDays) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Reps", item.reps)
                )
                .foregroundStyle(Calendar.current.isDateInToday(item.day) ? Theme.accent : Theme.accent.opacity(0.5))
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .frame(height: 140)
        }
        .card()
    }

    @ViewBuilder
    private var scanCard: some View {
        if let latest = scans.first {
            let breakdown = latest.breakdown
            let level = latest.level
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Your Face Score",
                              subtitle: "Scanned " + latest.date.formatted(.relative(presentation: .named)))
                NavigationLink {
                    ScanResultView(scan: latest)
                } label: {
                    HStack(spacing: 16) {
                        ScoreGauge(score: breakdown.overall, title: "", size: 76, lineWidth: 9)
                        VStack(alignment: .leading, spacing: 6) {
                            Label(level.title, systemImage: level.symbol)
                                .font(.headline)
                                .foregroundStyle(level.color)
                            if scans.count > 1 {
                                DeltaBadge(delta: breakdown.overall - scans[1].overallScore)
                            }
                            if let weakest = breakdown.weakest {
                                Text("Focus next: \(weakest.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    ForEach(FacePillar.allCases) { pillar in
                        VStack(spacing: 4) {
                            Text(breakdown.value(for: pillar).map { "\(Int($0.rounded()))" } ?? "–")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(pillar.color)
                            Text(pillar.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if let focus = latest.focusAreas.first,
                   let exercise = ExerciseLibrary.recommended(forFinding: focus).first {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack {
                            Text("Suggested:").foregroundStyle(.secondary)
                            Label(exercise.name, systemImage: exercise.symbol)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }

                Button("Scan again") { scanning = true }
                    .buttonStyle(.bordered)
            }
            .card()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("Get your face baseline", systemImage: "faceid")
                    .font(.title3.bold())
                Text("A \(Int(ScanStep.totalDuration))-second 3D scan gives you a Face Score for symmetry, mobility, control and relaxation, so you can track real progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Take first scan") { scanning = true }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.secondary))
            }
            .card()
        }
    }
}
