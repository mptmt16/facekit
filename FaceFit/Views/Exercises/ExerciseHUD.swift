import SwiftUI

/// On-camera coaching overlay: cue, activation ring, hold timer, reps and symmetry.
struct ExerciseHUD: View {
    let engine: ExerciseEngine
    let exerciseNumber: Int
    let exerciseCount: Int
    let isSimulated: Bool
    @Binding var showMesh: Bool
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            topBar
            Spacer()
            switch engine.phase {
            case .getReady:
                getReadyCard
            case .active, .rest:
                workCard
            case .finished:
                finishedCard
            }
        }
        .padding()
        .overlay(alignment: .top) {
            if !engine.faceVisible, engine.phase != .finished {
                Label("Face not detected — hold your phone at eye level", systemImage: "faceid")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange, in: Capsule())
                    .padding(.top, 76)
            }
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .foregroundStyle(.primary)

            Spacer()

            VStack(spacing: 2) {
                Text(engine.exercise.name).font(.headline)
                if exerciseCount > 1 {
                    Text("Exercise \(exerciseNumber) of \(exerciseCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            if isSimulated {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Button {
                    showMesh.toggle()
                } label: {
                    Image(systemName: showMesh ? "cube.transparent.fill" : "cube.transparent")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var getReadyCard: some View {
        VStack(spacing: 14) {
            Text("GET READY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("\(engine.countdown)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.default, value: engine.countdown)
            Text(engine.exercise.poses.map(\.cue).joined(separator: " → "))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(engine.exercise.steps, id: \.self) { step in
                    Label(step, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if engine.exercise.usesHeadPose {
                Text("Look straight ahead during the countdown to calibrate.")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var workCard: some View {
        VStack(spacing: 18) {
            Text(engine.phase == .rest ? "Relax" : engine.currentPose.cue)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(spacing: 24) {
                activationRing
                VStack(alignment: .leading, spacing: 14) {
                    stat(title: "Reps", value: "\(engine.repsCompleted)/\(engine.exercise.reps)")
                    if engine.exercise.poses.count > 1 {
                        stat(title: "Move", value: "\(engine.poseIndex + 1)/\(engine.exercise.poses.count)")
                    }
                    if engine.phase == .active, let symmetry = engine.symmetry {
                        stat(title: "Symmetry", value: "\(Int(symmetry * 100))%",
                             color: Theme.color(forScore: symmetry * 100))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                ForEach(0..<engine.exercise.reps, id: \.self) { rep in
                    Capsule()
                        .fill(rep < engine.repsCompleted ? Theme.accent : Color.white.opacity(0.2))
                        .frame(height: 6)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var activationRing: some View {
        ZStack {
            ProgressRing(progress: min(1, engine.progress), lineWidth: 14, color: ringColor)
            ProgressRing(progress: engine.holdProgress, lineWidth: 7, color: .white, trackOpacity: 0)
                .padding(22)
            VStack(spacing: 0) {
                if engine.phase == .rest {
                    Image(systemName: "wind")
                        .font(.title)
                    Text(engine.restRemaining > 0 ? "\(Int(engine.restRemaining.rounded(.up)))s" : "release")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                } else if engine.isHolding {
                    Text(String(format: "%.1f", max(0, engine.exercise.holdSeconds * (1 - engine.holdProgress))))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("HOLD")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("\(Int(min(engine.progress, 1.5) * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("of target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 140, height: 140)
    }

    private var ringColor: Color {
        switch engine.phase {
        case .rest: Color.white.opacity(0.4)
        default: engine.progress >= 1 || engine.isHolding ? Theme.accent : Theme.warm
        }
    }

    private var finishedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("\(engine.exercise.name) complete").font(.title3.bold())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func stat(title: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}
