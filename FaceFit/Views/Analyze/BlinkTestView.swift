import SwiftUI
import SwiftData

/// 60-second eye comfort test: the user reads while TrueDepth counts full and partial blinks.
struct BlinkTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.haptics) private var haptics = true

    @State private var tracker = FaceTracker()
    @State private var engine = BlinkTestEngine()
    @State private var savedTest: BlinkTest?

    var body: some View {
        NavigationStack {
            Group {
                if let savedTest {
                    BlinkTestResultView(test: savedTest)
                } else if engine.state == .running {
                    runningView
                } else {
                    introView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(savedTest == nil ? "Cancel" : "Done") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: prepare)
        .onDisappear(perform: tearDown)
    }

    private var introView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "eye")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
                Text("Eye Comfort Test").font(.largeTitle.bold())
                Text("For 60 seconds, read the text on screen at your normal pace. The TrueDepth camera counts your full and incomplete blinks and how long you stare without blinking.")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Hold your phone where you normally read", systemImage: "iphone")
                    Label("Don't think about blinking — just read", systemImage: "text.alignleft")
                    Label("Takes one minute", systemImage: "timer")
                }
                .font(.subheadline)

                FaceCameraView(tracker: tracker, showMesh: false)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button("Start test") { engine.begin() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!engine.faceVisible)
                if !engine.faceVisible {
                    Text("Make sure your face is visible to start.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
        }
    }

    private var runningView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: engine.progress, lineWidth: 6)
                    Text("\(Int(max(0, BlinkTestEngine.testSeconds - engine.elapsed).rounded(.up)))")
                        .font(.headline.monospacedDigit())
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading test").font(.headline)
                    Text(engine.faceVisible ? "Keep reading naturally" : "Face lost — timer paused")
                        .font(.caption)
                        .foregroundStyle(engine.faceVisible ? Color.secondary : Color.orange)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(engine.blinkCount)")
                        .font(.title2.bold().monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(.snappy, value: engine.blinkCount)
                    Text("blinks").font(.caption2).foregroundStyle(.secondary)
                }
                FaceCameraView(tracker: tracker, showMesh: false)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding()
            .background(Theme.card)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Self.passage, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.title3)
                            .lineSpacing(6)
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Flow

    private func prepare() {
        guard !tracker.isRunning, savedTest == nil else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        tracker.simulateNaturalBlinks = true
        tracker.onSample = { [engine] sample in engine.handle(sample) }
        let feedback = UIImpactFeedbackGenerator(style: .soft)
        let hapticsOn = haptics
        engine.onBlink = {
            if hapticsOn { feedback.impactOccurred(intensity: 0.4) }
        }
        engine.onFinished = { result in
            tracker.stop()
            let test = BlinkTest(result: result)
            modelContext.insert(test)
            try? modelContext.save()
            withAnimation { savedTest = test }
        }
        tracker.start()
    }

    private func tearDown() {
        UIApplication.shared.isIdleTimerDisabled = false
        tracker.onSample = nil
        engine.onBlink = nil
        engine.onFinished = nil
        tracker.stop()
    }

    static let passage: [String] = [
        "Every blink spreads a thin film of tears across the surface of your eyes. That film keeps each eye smooth, clear and comfortable, and it washes away tiny particles of dust.",
        "During a relaxed conversation most people blink fifteen to twenty times a minute. While reading or looking at a screen, that number can fall by half, because the brain quietly holds back blinks while it concentrates.",
        "Blinks can also become incomplete. The upper eyelid starts to fall but never meets the lower one, so part of the eye stays exposed. Over a long day, incomplete blinks are a common reason eyes feel dry, gritty or tired.",
        "Good screen habits help. Keep your phone at a comfortable distance, raise the text size until reading feels effortless, and match screen brightness to the room around you.",
        "Short, frequent breaks matter more than long ones. Every twenty minutes, look at something far away for about twenty seconds. Let your shoulders drop, breathe out slowly and blink fully a few times.",
        "Your face and your eyes work together. Smoothing the brow, softening the jaw and unclenching the lips often makes blinking feel easier too, which is why FaceFit pairs eye checks with relaxation exercises.",
        "Keep reading at your normal pace. There is nothing special to do — just read, and let FaceFit quietly count your blinks until the timer finishes.",
    ]
}

struct BlinkTestResultView: View {
    let test: BlinkTest

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    ScoreGauge(score: test.score, title: "Eye comfort", size: 130, lineWidth: 14)
                    Text(test.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .card()

                HStack(spacing: 12) {
                    StatTile(title: "Blinks / min", value: String(format: "%.0f", test.blinksPerMinute), symbol: "eye")
                    StatTile(title: "Incomplete", value: "\(Int((test.partialRatio * 100).rounded()))%",
                             symbol: "eye.trianglebadge.exclamationmark", color: Theme.warm)
                    StatTile(title: "Longest stare", value: String(format: "%.0fs", test.longestGap),
                             symbol: "timer", color: Theme.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "What this means")
                    Text("A comfortable reading blink rate is roughly 12–25 per minute, with almost every blink fully closing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(test.advice, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb")
                            .font(.subheadline)
                    }
                }
                .card()

                if test.score < 70, let exercise = ExerciseLibrary.exercise(id: "eye-squeeze") {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack {
                            ExerciseRow(exercise: exercise)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }

                Text("This test is a wellness check, not a medical diagnosis. See an optometrist if your eyes are often sore, red or blurry.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .navigationTitle("Eye comfort")
    }
}
