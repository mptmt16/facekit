import SwiftUI
import ARKit
import SceneKit

/// Mirror-style front camera feed with an optional live 3D face mesh overlay.
/// Falls back to an animated face drawing when running in demo mode.
struct FaceCameraView: View {
    let tracker: FaceTracker
    var showMesh: Bool = true

    var body: some View {
        if tracker.isSimulated {
            SimulatedFacePreview(sample: tracker.sample)
        } else {
            ARFaceMeshView(session: tracker.session, showMesh: showMesh)
        }
    }
}

private struct ARFaceMeshView: UIViewRepresentable {
    let session: ARSession
    let showMesh: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.delegate = context.coordinator
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = false
        view.rendersContinuously = true
        context.coordinator.showMesh = showMesh
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        context.coordinator.showMesh = showMesh
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        private var meshNode: SCNNode?

        var showMesh = true {
            didSet { meshNode?.isHidden = !showMesh }
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let device = renderer.device,
                  let geometry = ARSCNFaceGeometry(device: device) else { return nil }

            if let material = geometry.firstMaterial {
                material.fillMode = .lines
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(red: 0.35, green: 0.95, blue: 0.85, alpha: 0.6)
            }
            let node = SCNNode(geometry: geometry)
            node.isHidden = !showMesh
            meshNode = node
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry else { return }
            geometry.update(from: faceAnchor.geometry)
        }
    }
}

/// A simple cartoon face driven by the same signals as the real camera, for demo mode.
struct SimulatedFacePreview: View {
    let sample: FaceSample

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                let s = sample
                let unit = min(size.width, size.height) * 0.3
                let center = CGPoint(
                    x: size.width / 2 + CGFloat(s.head.yaw) * unit / 90,
                    y: size.height * 0.42 - CGFloat(s.head.pitch) * unit / 90
                )
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: .degrees(-s.head.roll))

                let puff = CGFloat(s.value(.cheekPuff)) * 0.12
                let head = CGRect(x: -unit * (0.8 + puff), y: -unit, width: unit * (1.6 + puff * 2), height: unit * 2.1)
                context.stroke(Path(ellipseIn: head), with: .color(Theme.accent.opacity(0.8)), lineWidth: 3)

                for side in [-1.0, 1.0] {
                    let blink = side < 0 ? s.value(.eyeBlinkLeft) : s.value(.eyeBlinkRight)
                    let brow = max(s.value(.browInnerUp), side < 0 ? s.value(.browOuterUpLeft) : s.value(.browOuterUpRight))
                    let eyeHeight = unit * 0.16 * CGFloat(max(0.08, 1 - blink))
                    let eye = CGRect(x: CGFloat(side) * unit * 0.35 - unit * 0.14, y: -unit * 0.25 - eyeHeight / 2,
                                     width: unit * 0.28, height: eyeHeight)
                    context.fill(Path(ellipseIn: eye), with: .color(.white.opacity(0.85)))

                    var browPath = Path()
                    let browY = -unit * 0.48 - CGFloat(brow) * unit * 0.18
                    browPath.move(to: CGPoint(x: CGFloat(side) * unit * 0.18, y: browY))
                    browPath.addLine(to: CGPoint(x: CGFloat(side) * unit * 0.55, y: browY - unit * 0.04))
                    context.stroke(browPath, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }

                let smile = (s.value(.mouthSmileLeft) + s.value(.mouthSmileRight)) / 2
                let open = s.value(.jawOpen)
                let pucker = s.value(.mouthPucker)
                let halfWidth = unit * CGFloat(0.28 + smile * 0.18 - pucker * 0.12)
                let mouthY = unit * 0.55
                var mouth = Path()
                mouth.move(to: CGPoint(x: -halfWidth, y: mouthY - CGFloat(smile) * unit * 0.12))
                mouth.addQuadCurve(to: CGPoint(x: halfWidth, y: mouthY - CGFloat(smile) * unit * 0.12),
                                   control: CGPoint(x: 0, y: mouthY + unit * CGFloat(0.1 + open * 0.45)))
                mouth.addQuadCurve(to: CGPoint(x: -halfWidth, y: mouthY - CGFloat(smile) * unit * 0.12),
                                   control: CGPoint(x: 0, y: mouthY))
                context.stroke(mouth, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
            }
            Label("Demo mode — no TrueDepth camera, data is simulated", systemImage: "wand.and.stars")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 110)
        }
    }
}
