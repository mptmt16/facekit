import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \ExerciseSession.date, order: .reverse) private var sessions: [ExerciseSession]
    @Query(sort: \FaceScan.date, order: .reverse) private var scans: [FaceScan]

    @State private var routineRunning = false
    @State private var scanning = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    routineCard
                    statsRow
                    weekChart
                    scanCard
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
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Latest face scan",
                              subtitle: latest.date.formatted(.relative(presentation: .named)))
                NavigationLink {
                    ScanResultView(scan: latest)
                } label: {
                    HStack {
                        ScoreGauge(score: latest.overallScore, title: "Overall", size: 64)
                        Spacer()
                        ScoreGauge(score: latest.symmetryScore, title: "Symmetry", size: 48, lineWidth: 6)
                        ScoreGauge(score: latest.rangeScore, title: "Range", size: 48, lineWidth: 6)
                        ScoreGauge(score: latest.relaxationScore, title: "Relaxed", size: 48, lineWidth: 6)
                    }
                }
                .buttonStyle(.plain)

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
                Text("A 40-second 3D scan measures your symmetry, expression range and resting tension so you can track real progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Take first scan") { scanning = true }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.secondary))
            }
            .card()
        }
    }
}
