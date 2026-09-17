import SwiftUI

/// Full-screen expression-matching game.
struct FaceChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.voiceCoach) private var voiceCoach = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.challengeHighScore) private var highScore = 0
    @AppStorage(SettingsKey.challengeGames) private var gamesPlayed = 0

    @State private var tracker = FaceTracker()
    @State private var engine = ChallengeEngine()
    @State private var coach: Coach?
    @State private var isNewHighScore = false

    var body: some View {
        ZStack {
            FaceCameraView(tracker: tracker, showMesh: false)
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.8)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                topBar
                Spacer()
                switch engine.phase {
                case .ready:
                    readyCard
                case .countdown:
                    countdownCard
                case .playing:
                    promptCard
                case .finished:
                    resultsCard
                }
            }
            .padding()
        }
        .background(Color.black)
        .statusBarHidden()
        .onAppear(perform: prepare)
        .onDisappear(perform: tearDown)
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .foregroundStyle(.primary)

            Spacer()

            if engine.phase == .playing {
                Label("\(Int(engine.timeRemaining.rounded(.up)))s", systemImage: "timer")
                    .font(.headline.monospacedDigit())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                Text("\(engine.score)")
                    .font(.title3.bold().monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.snappy, value: engine.score)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var readyCard: some View {
        VStack(spacing: 14) {
            Text("🎭").font(.system(size: 56))
            Text("Face Challenge").font(.title.bold())
            Text("Copy as many expressions as you can in 60 seconds. Faster matches and streaks earn bonus points.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                StatTile(title: "High score", value: "\(highScore)", symbol: "trophy.fill", color: Theme.warm)
                StatTile(title: "Games played", value: "\(gamesPlayed)", symbol: "gamecontroller.fill", color: Theme.secondary)
            }
            Button("Start") {
                isNewHighScore = false
                engine.start()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!engine.faceVisible)
            if !engine.faceVisible {
                Text("Show your face to the camera to start.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var countdownCard: some View {
        VStack(spacing: 8) {
            Text("GET READY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("\(engine.countdown)")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: engine.countdown)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var promptCard: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    ProgressRing(progress: min(1, engine.progress), lineWidth: 12,
                                 color: engine.progress >= 1 ? Theme.accent : Theme.warm)
                    Text(engine.prompt.emoji)
                        .font(.system(size: 72))
                }
                .frame(width: 150, height: 150)

                if engine.lastPoints > 0 {
                    Text("+\(engine.lastPoints)")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5), in: Capsule())
                        .id(engine.awardCount)
                        .transition(.scale.combined(with: .opacity))
                        .offset(x: 30, y: -6)
                }
            }

            Text(engine.prompt.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            ProgressView(value: engine.promptRemaining, total: ChallengeEngine.promptSeconds)
                .tint(.white)

            HStack {
                Label("\(engine.matches) matched", systemImage: "checkmark.circle.fill")
                Spacer()
                if engine.streak > 1 {
                    Label("\(engine.streak) streak", systemImage: "flame.fill")
                        .foregroundStyle(Theme.warm)
                }
            }
            .font(.subheadline.bold())

            if !engine.faceVisible {
                Text("Face not detected")
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.spring(duration: 0.3), value: engine.awardCount)
    }

    private var resultsCard: some View {
        VStack(spacing: 14) {
            Text(isNewHighScore ? "🏆 New high score!" : "Time's up!")
                .font(.title2.bold())
            Text("\(engine.score)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 10) {
                StatTile(title: "Matched", value: "\(engine.matches)", symbol: "checkmark.circle.fill")
                StatTile(title: "Best streak", value: "\(engine.bestStreak)", symbol: "flame.fill", color: Theme.warm)
                StatTile(title: "Fastest", value: engine.fastestMatch.map { String(format: "%.1fs", $0) } ?? "–",
                         symbol: "bolt.fill", color: Theme.secondary)
            }
            HStack(spacing: 12) {
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("Play again") {
                    isNewHighScore = false
                    engine.start()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Flow

    private func prepare() {
        guard coach == nil else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        let coach = Coach(voiceEnabled: voiceCoach, hapticsEnabled: haptics)
        self.coach = coach

        tracker.onSample = { [engine] sample in engine.handle(sample) }
        engine.onEvent = { event in
            switch event {
            case .started(let prompt):
                coach.tap()
                coach.say(prompt.title)
            case .matched(_, let next):
                coach.success()
                coach.say(next.title)
            case .missed(let next):
                coach.warning()
                coach.say(next.title)
            case .finished(let score):
                gamesPlayed += 1
                if score > highScore {
                    highScore = score
                    isNewHighScore = true
                    coach.say("New high score! \(score) points.")
                } else {
                    coach.say("Time's up. \(score) points.")
                }
                coach.success()
            }
        }
        tracker.start()
    }

    private func tearDown() {
        UIApplication.shared.isIdleTimerDisabled = false
        tracker.onSample = nil
        engine.onEvent = nil
        tracker.stop()
        coach?.finish()
    }
}
