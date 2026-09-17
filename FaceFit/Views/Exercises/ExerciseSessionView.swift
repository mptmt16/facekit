import SwiftUI
import SwiftData

/// Runs one exercise or a whole routine: camera + live coaching, then a summary.
struct ExerciseSessionView: View {
    let exercises: [Exercise]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.voiceCoach) private var voiceCoach = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.showMesh) private var showMesh = true
    @AppStorage(SettingsKey.difficulty) private var difficulty = 1.0

    @State private var tracker = FaceTracker()
    @State private var engine: ExerciseEngine?
    @State private var coach: Coach?
    @State private var index = 0
    @State private var results: [ExerciseResult] = []
    @State private var betweenExercises = false
    @State private var showingSummary = false

    var body: some View {
        ZStack {
            if showingSummary {
                SessionSummaryView(results: results) { dismiss() }
            } else {
                FaceCameraView(tracker: tracker, showMesh: showMesh)
                    .ignoresSafeArea()
                scrims
                if let engine {
                    ExerciseHUD(
                        engine: engine,
                        exerciseNumber: index + 1,
                        exerciseCount: exercises.count,
                        isSimulated: tracker.isSimulated,
                        showMesh: $showMesh,
                        onClose: endSession
                    )
                }
                if betweenExercises, index + 1 < exercises.count {
                    nextUpCard(exercises[index + 1])
                }
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: startSession)
        .onDisappear(perform: tearDown)
    }

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .frame(height: 380)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func nextUpCard(_ next: Exercise) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("Nice work!").font(.title2.bold())
            Text("Next: \(next.name)").foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Flow

    private func startSession() {
        guard engine == nil, !exercises.isEmpty else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        coach = Coach(voiceEnabled: voiceCoach, hapticsEnabled: haptics)
        tracker.start()
        startExercise(at: 0)
    }

    private func startExercise(at newIndex: Int) {
        let exercise = exercises[newIndex]
        let newEngine = ExerciseEngine(exercise: exercise, difficulty: difficulty)
        newEngine.onEvent = { event in handle(event) }
        tracker.onSample = { [weak newEngine] sample in newEngine?.handle(sample) }
        withAnimation {
            index = newIndex
            betweenExercises = false
            engine = newEngine
        }
        coach?.say("\(exercise.name). Get ready.")
    }

    private func handle(_ event: ExerciseEngine.Event) {
        guard let coach else { return }
        switch event {
        case .started(let cue):
            coach.tap()
            coach.say(cue)
        case .holdStarted:
            coach.tap()
            coach.say("Hold", interrupt: false)
        case .holdBroken:
            break
        case .nextPose(let cue):
            coach.tap()
            coach.say(cue)
        case .repCompleted(let count):
            coach.success()
            let remaining = (engine?.exercise.reps ?? 0) - count
            coach.say(remaining == 1 ? "\(count). Relax. One more." : "\(count). Relax.")
        case .nextRep(let cue):
            coach.say(cue)
        case .finished:
            finishCurrentExercise()
        }
    }

    private func finishCurrentExercise() {
        guard let engine else { return }
        record(engine.result)
        coach?.success()

        if index + 1 < exercises.count {
            let nextIndex = index + 1
            withAnimation { betweenExercises = true }
            coach?.say("Nice work. Next up: \(exercises[nextIndex].name).")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard betweenExercises, !showingSummary else { return }
                startExercise(at: nextIndex)
            }
        } else {
            coach?.say("Workout complete. Great job!")
            tracker.stop()
            showingSummary = true
        }
    }

    private func endSession() {
        if let engine, engine.phase != .finished, engine.repsCompleted > 0 {
            record(engine.result)
        }
        betweenExercises = false
        tracker.stop()
        if results.isEmpty {
            dismiss()
        } else {
            showingSummary = true
        }
    }

    private func record(_ result: ExerciseResult) {
        guard result.repsCompleted > 0 else { return }
        results.append(result)
        modelContext.insert(ExerciseSession(result: result))
        try? modelContext.save()
    }

    private func tearDown() {
        UIApplication.shared.isIdleTimerDisabled = false
        tracker.onSample = nil
        engine?.onEvent = nil
        tracker.stop()
        coach?.finish()
    }
}
