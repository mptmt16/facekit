import AVFoundation
import UIKit

/// Voice cues and haptics, so exercises can be followed without watching the screen
/// (essential when your eyes are closed or your head is turned).
final class Coach {
    var voiceEnabled: Bool
    var hapticsEnabled: Bool

    private let synthesizer = AVSpeechSynthesizer()
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    init(voiceEnabled: Bool, hapticsEnabled: Bool) {
        self.voiceEnabled = voiceEnabled
        self.hapticsEnabled = hapticsEnabled
        if voiceEnabled {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        }
        impact.prepare()
        notification.prepare()
    }

    func say(_ text: String, interrupt: Bool = true) {
        guard voiceEnabled else { return }
        if interrupt, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        synthesizer.speak(utterance)
    }

    func tap() {
        guard hapticsEnabled else { return }
        impact.impactOccurred()
    }

    func success() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func warning() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Stops speech and lets other audio (music, podcasts) return to full volume.
    func finish() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
