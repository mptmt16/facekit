import SwiftUI
import AVFoundation

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private let pages: [(symbol: String, title: String, text: String)] = [
        ("face.smiling", "Train your face",
         "Guided facial exercises with real-time coaching. FaceFit counts your reps and only scores a hold when the right muscles are working."),
        ("faceid", "Built on TrueDepth",
         "Your iPhone's front 3D camera tracks 52 facial movements and a 1,220-point face mesh — precise enough to measure left/right balance in millimetres."),
        ("chart.line.uptrend.xyaxis", "Analyze & improve",
         "Face scans score your symmetry, expression range and hidden tension, then recommend exercises and track your progress."),
        ("lock.shield", "Private by design",
         "Everything is processed on your iPhone. No photos or face data ever leave your device."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    let item = pages[index]
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: item.symbol)
                            .font(.system(size: 88, weight: .light))
                            .foregroundStyle(Theme.accent)
                            .frame(height: 120)
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(item.text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                Button(page == pages.count - 1 ? "Allow camera & start" : "Continue") {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        AVCaptureDevice.requestAccess(for: .video) { _ in
                            DispatchQueue.main.async { onFinish() }
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("FaceFit is a wellness tool, not a medical device. If you have facial paralysis, TMJ pain or a recent injury, check with a clinician first.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
