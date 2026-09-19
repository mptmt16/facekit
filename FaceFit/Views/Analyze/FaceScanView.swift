import SwiftUI
import SwiftData

/// Full-screen guided scan: intro → 8 recorded steps → saved result.
struct FaceScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.voiceCoach) private var voiceCoach = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.saveFacePhoto) private var saveFacePhoto = true

    @State private var tracker = FaceTracker()
    @State private var engine = FaceScanEngine()
    @State private var coach: Coach?
    @State private var savedScan: FaceScan?

    var body: some View {
        Group {
            if let savedScan {
                NavigationStack {
                    ScanResultView(scan: savedScan)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            } else {
                scanner
            }
        }
        .onAppear(perform: prepare)
        .onDisappear(perform: tearDown)
    }

    private var scanner: some View {
        ZStack {
            FaceCameraView(tracker: tracker, showMesh: true)
                .ignoresSafeArea()

            // Oval guide for framing
            Ellipse()
                .stroke(engine.faceVisible ? Theme.accent : Color.white.opacity(0.6),
                        style: StrokeStyle(lineWidth: 3, dash: engine.faceVisible ? [] : [10, 8]))
                .frame(width: 250, height: 330)
                .offset(y: -80)
                .allowsHitTesting(false)

            VStack {
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
                    if engine.state == .running {
                        Text("\(engine.stepIndex + 1) / \(engine.steps.count)")
                            .font(.subheadline.bold().monospacedDigit())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                Spacer()
                switch engine.state {
                case .intro:
                    introCard
                case .running:
                    stepCard
                case .finished:
                    ProgressView("Analyzing your face…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding()
        }
        .background(Color.black)
        .statusBarHidden()
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Before you start").font(.title3.bold())
            Label("Hold your phone at eye level, about 30 cm away", systemImage: "iphone")
            Label("Face a light source; avoid strong backlight", systemImage: "sun.max")
            Label("Remove glasses and pull hair off your forehead", systemImage: "eyeglasses")
            Label("Follow the voice cues — some steps close your eyes", systemImage: "speaker.wave.2")
            Button("Begin scan") {
                engine.begin()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!engine.faceVisible)
            if !engine.faceVisible {
                Text("Position your face inside the oval to begin.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var stepCard: some View {
        let step = engine.currentStep
        return VStack(spacing: 14) {
            Image(systemName: step.symbol)
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text(step.title).font(.title2.bold())
            Text(step.instruction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !engine.faceVisible {
                Label("Face lost — the scan pauses until you're back in view", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
            } else if engine.isLeadIn {
                Text("Get ready…").font(.footnote.bold()).foregroundStyle(Theme.warm)
            } else {
                Text("Recording").font(.footnote.bold()).foregroundStyle(Theme.accent)
            }

            ProgressView(value: engine.stepProgress)
                .tint(Theme.accent)
            ProgressView(value: engine.overallProgress)
                .tint(Theme.secondary)
                .scaleEffect(x: 1, y: 0.6)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Flow

    private func prepare() {
        guard coach == nil else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        let coach = Coach(voiceEnabled: voiceCoach, hapticsEnabled: haptics)
        self.coach = coach

        tracker.includeGeometry = true
        tracker.onSample = { [engine] sample in engine.handle(sample) }
        engine.onStepStarted = { step in
            coach.tap()
            coach.say(step.voice)
        }
        engine.onRecordingStarted = { [engine, tracker] step in
            // Grab the color 3D face while the face is relaxed and looking straight ahead.
            guard saveFacePhoto, case .neutral = step.kind else { return }
            tracker.captureTexture { texture, jpeg in
                engine.attachTexture(texture, jpeg: jpeg)
                // Skin analysis is heavy, so it runs off the main thread while the scan continues.
                Task.detached(priority: .userInitiated) {
                    guard let report = SkinAnalyzer.analyze(jpeg: jpeg, texture: texture) else { return }
                    await MainActor.run { applySkin(report) }
                }
            }
        }
        engine.onFinished = { outcome in
            coach.success()
            coach.say("Scan complete.")
            save(outcome)
        }
        tracker.start()
    }

    @MainActor
    private func applySkin(_ report: SkinReport) {
        if let savedScan {
            // The scan was already saved, so attach the skin results to it.
            savedScan.setSkin(report)
            try? modelContext.save()
        } else {
            engine.attachSkin(report)
        }
    }

    private func save(_ outcome: ScanOutcome) {
        tracker.stop()
        let scan = FaceScan(outcome: outcome)
        modelContext.insert(scan)
        try? modelContext.save()
        withAnimation { savedScan = scan }
    }

    private func tearDown() {
        UIApplication.shared.isIdleTimerDisabled = false
        tracker.onSample = nil
        engine.onStepStarted = nil
        engine.onRecordingStarted = nil
        engine.onFinished = nil
        tracker.stop()
        coach?.finish()
    }
}
