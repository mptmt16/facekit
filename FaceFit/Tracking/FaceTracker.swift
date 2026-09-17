import ARKit
import Observation

/// Owns the ARKit face-tracking session and turns raw frames into `FaceSample`s.
///
/// On devices without a TrueDepth camera (including the Simulator) it falls back to a
/// simulated face so the whole app can still be explored.
@Observable
final class FaceTracker: NSObject, ARSessionDelegate {
    static var isTrueDepthAvailable: Bool { ARFaceTrackingConfiguration.isSupported }

    let session = ARSession()

    /// Latest sample, published at up to 30 Hz for SwiftUI.
    private(set) var sample: FaceSample = .empty
    private(set) var isRunning = false
    private(set) var isSimulated = false
    private(set) var errorMessage: String?

    /// Copy mesh vertices into each sample (only needed by the face scan).
    @ObservationIgnored var includeGeometry = false
    /// Demo mode only: simulate quick natural blinks instead of slow eye-closing waves.
    @ObservationIgnored var simulateNaturalBlinks = false
    /// Receives every processed sample. Engines hook in here.
    @ObservationIgnored var onSample: ((FaceSample) -> Void)?

    @ObservationIgnored private var lastProcessed: TimeInterval = 0
    @ObservationIgnored private var cachedIndices: [Int16] = []
    @ObservationIgnored private var simulationTimer: Timer?
    @ObservationIgnored private var simulationStart: TimeInterval = 0
    @ObservationIgnored private var textureRequest: ((FaceTexture, Data) -> Void)?

    override init() {
        super.init()
        session.delegate = self
    }

    /// Captures a color 3D face from the next frame where the face is frontal with eyes open.
    /// Does nothing in demo mode.
    func captureTexture(_ completion: @escaping (FaceTexture, Data) -> Void) {
        guard Self.isTrueDepthAvailable else { return }
        textureRequest = completion
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        if Self.isTrueDepthAvailable {
            isSimulated = false
            let configuration = ARFaceTrackingConfiguration()
            configuration.maximumNumberOfTrackedFaces = 1
            configuration.isLightEstimationEnabled = false
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        } else {
            startSimulation()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        textureRequest = nil
        simulationTimer?.invalidate()
        simulationTimer = nil
        if !isSimulated {
            session.pause()
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // TrueDepth delivers 60 fps; 30 Hz is plenty for coaching and halves the work.
        guard frame.timestamp - lastProcessed >= 1.0 / 32.0 else { return }
        lastProcessed = frame.timestamp

        guard let face = frame.anchors.lazy.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
            publish(FaceSample(
                timestamp: frame.timestamp, isTracked: false, blendShapes: [:], head: sample.head,
                leftEye: .zero, rightEye: .zero, vertices: [], triangleIndices: []
            ))
            return
        }

        var shapes: [BlendShape: Double] = [:]
        shapes.reserveCapacity(face.blendShapes.count)
        for (key, value) in face.blendShapes {
            shapes[key] = value.doubleValue
        }

        var vertices: [SIMD3<Float>] = []
        if includeGeometry {
            vertices = face.geometry.vertices
            if cachedIndices.isEmpty {
                cachedIndices = face.geometry.triangleIndices
            }
        }

        let head = HeadPose.from(face: face.transform, camera: frame.camera.transform)
        if let request = textureRequest,
           Swift.max(shapes[.eyeBlinkLeft] ?? 0, shapes[.eyeBlinkRight] ?? 0) < 0.3,
           abs(head.yaw) < 12, abs(head.pitch) < 12,
           let capture = FaceTextureCapture.make(frame: frame, anchor: face) {
            textureRequest = nil
            request(capture.texture, capture.jpeg)
        }

        let left = face.leftEyeTransform.columns.3
        let right = face.rightEyeTransform.columns.3
        publish(FaceSample(
            timestamp: frame.timestamp,
            isTracked: true,
            blendShapes: shapes,
            head: head,
            leftEye: SIMD3<Float>(left.x, left.y, left.z),
            rightEye: SIMD3<Float>(right.x, right.y, right.z),
            vertices: vertices,
            triangleIndices: includeGeometry ? cachedIndices : []
        ))
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        isRunning = false
    }

    func sessionWasInterrupted(_ session: ARSession) {
        errorMessage = "Camera paused"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        errorMessage = nil
        guard isRunning, let configuration = session.configuration else { return }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func publish(_ newSample: FaceSample) {
        sample = newSample
        onSample?(newSample)
    }

    // MARK: - Simulation (no TrueDepth camera)

    private func startSimulation() {
        isSimulated = true
        simulationStart = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.simulateFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        simulationTimer = timer
    }

    /// Slow, plateaued waves so every exercise can be completed hands-free in demo mode.
    private func simulateFrame() {
        let now = ProcessInfo.processInfo.systemUptime
        let t = now - simulationStart
        let phase = 2 * Double.pi * t / 10
        let wave = min(1, max(0, 1.3 * (0.5 - 0.5 * cos(phase))))
        let tensionShapes: Set<BlendShape> = [
            .browDownLeft, .browDownRight, .eyeSquintLeft, .eyeSquintRight,
            .mouthPressLeft, .mouthPressRight, .mouthFrownLeft, .mouthFrownRight,
            .jawForward, .cheekSquintLeft, .cheekSquintRight,
        ]

        var shapes: [BlendShape: Double] = [:]
        for shape in BlendShapeCatalog.allShapes {
            if simulateNaturalBlinks, shape == .eyeBlinkLeft || shape == .eyeBlinkRight {
                // A full blink every 3.4 s, plus an incomplete blink every third cycle.
                let cycle = t.truncatingRemainder(dividingBy: 3.4)
                let isPartialCycle = Int(t / 3.4) % 3 == 0
                if cycle < 0.2 {
                    shapes[shape] = 0.9
                } else if isPartialCycle, cycle > 1.6, cycle < 1.8 {
                    shapes[shape] = 0.35
                } else {
                    shapes[shape] = 0.05
                }
            } else if tensionShapes.contains(shape) {
                shapes[shape] = 0.06 + 0.03 * sin(t * 1.7)
            } else if shape.rawValue.hasSuffix("_R") {
                shapes[shape] = wave * 0.9   // a little asymmetry makes the analysis interesting
            } else {
                shapes[shape] = wave
            }
        }

        publish(FaceSample(
            timestamp: now,
            isTracked: true,
            blendShapes: shapes,
            head: HeadPose(yaw: 40 * sin(phase), pitch: 30 * sin(phase), roll: 30 * sin(phase)),
            leftEye: SIMD3<Float>(0.031, 0.025, 0.02),
            rightEye: SIMD3<Float>(-0.031, 0.025, 0.02),
            vertices: [],
            triangleIndices: []
        ))
    }
}
