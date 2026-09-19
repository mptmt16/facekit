import SwiftUI
import ARKit
import SceneKit
import simd

/// Animated 3D demo of an exercise, built from ARKit's own face model.
/// The same blend shapes the app measures drive the demo, so no stock footage is needed.
struct ExerciseDemoView: UIViewRepresentable {
    let exercise: Exercise

    func makeCoordinator() -> Coordinator { Coordinator(exercise: exercise) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        if let scene = context.coordinator.makeScene() {
            view.scene = scene
            view.pointOfView = context.coordinator.cameraNode
        }
        context.coordinator.start()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stop()
    }

    /// Whether a demo can be shown at all (needs ARKit's face model).
    static var isAvailable: Bool { ARFaceGeometry(blendShapes: [:]) != nil }

    final class Coordinator {
        private let exercise: Exercise
        private var timer: Timer?
        private var startedAt = Date()
        private weak var faceNode: SCNNode?
        private(set) var cameraNode: SCNNode?
        private var headAngles: [SIMD3<Float>] = []

        init(exercise: Exercise) {
            self.exercise = exercise
        }

        func makeScene() -> SCNScene? {
            guard let neutral = Self.geometry(for: [:]) else { return nil }
            let scene = SCNScene()

            let material = SCNMaterial()
            material.lightingModel = .blinn
            material.diffuse.contents = UIColor(red: 0.62, green: 0.68, blue: 0.75, alpha: 1)
            material.specular.contents = UIColor(white: 0.35, alpha: 1)
            neutral.materials = [material]

            let node = SCNNode(geometry: neutral)
            let morpher = SCNMorpher()
            morpher.calculationMode = .normalized
            morpher.targets = exercise.poses.compactMap { pose in
                Self.geometry(for: Self.blendShapes(for: pose))
            }
            node.morpher = morpher
            headAngles = exercise.poses.map { Self.headAngles(for: $0) }
            scene.rootNode.addChildNode(node)
            faceNode = node

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 420
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 900
            key.position = SCNVector3(0.2, 0.3, 0.5)
            key.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(key)

            let camera = SCNCamera()
            camera.zNear = 0.01
            camera.fieldOfView = 26
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, -0.01, 0.42)
            scene.rootNode.addChildNode(cameraNode)
            self.cameraNode = cameraNode

            return scene
        }

        func start() {
            guard timer == nil else { return }
            startedAt = Date()
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func stop() {
            timer?.invalidate()
            timer = nil
        }

        /// Each pose ramps in, holds, ramps out, then the next pose takes over.
        private func tick() {
            guard let faceNode, let morpher = faceNode.morpher, !morpher.targets.isEmpty else { return }
            let poseCount = morpher.targets.count
            let cycle: Double = 3.4
            let elapsed = Date().timeIntervalSince(startedAt)
            let index = Int(elapsed / cycle) % poseCount
            let phase = elapsed.truncatingRemainder(dividingBy: cycle)

            let weight: Double
            switch phase {
            case ..<0.8: weight = phase / 0.8
            case ..<2.2: weight = 1
            case ..<3.0: weight = 1 - (phase - 2.2) / 0.8
            default: weight = 0
            }
            let eased = 0.5 - 0.5 * cos(weight * Double.pi)

            for target in 0..<poseCount {
                morpher.setWeight(target == index ? CGFloat(eased) : 0, forTargetAt: target)
            }
            if index < headAngles.count {
                let angles = headAngles[index]
                faceNode.eulerAngles = SCNVector3(angles.x * Float(eased), angles.y * Float(eased), angles.z * Float(eased))
            }
        }

        // MARK: - Geometry

        static func geometry(for blendShapes: [BlendShape: NSNumber]) -> SCNGeometry? {
            guard let face = ARFaceGeometry(blendShapes: blendShapes) else { return nil }
            let positions = face.vertices.map { SCNVector3($0.x, $0.y, $0.z) }
            let normals = normals(vertices: face.vertices, indices: face.triangleIndices)
            let element = SCNGeometryElement(indices: face.triangleIndices, primitiveType: .triangles)
            return SCNGeometry(
                sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
                elements: [element]
            )
        }

        static func normals(vertices: [SIMD3<Float>], indices: [Int16]) -> [SCNVector3] {
            var sums = [SIMD3<Float>](repeating: .zero, count: vertices.count)
            var t = 0
            while t + 2 < indices.count {
                let a = Int(indices[t]), b = Int(indices[t + 1]), c = Int(indices[t + 2])
                t += 3
                guard a < vertices.count, b < vertices.count, c < vertices.count else { continue }
                let normal = simd_cross(vertices[b] - vertices[a], vertices[c] - vertices[a])
                sums[a] += normal
                sums[b] += normal
                sums[c] += normal
            }
            return sums.map { sum in
                let length = simd_length(sum)
                let unit = length > 0 ? sum / length : SIMD3<Float>(0, 0, 1)
                return SCNVector3(unit.x, unit.y, unit.z)
            }
        }

        /// The blend shapes a pose asks for, pushed a little further so the movement reads clearly.
        static func blendShapes(for pose: Pose) -> [BlendShape: NSNumber] {
            var shapes: [BlendShape: NSNumber] = [:]
            for requirement in pose.requirements where requirement.mode == .above {
                let value = Swift.min(1, requirement.target * 1.5)
                switch requirement.signal {
                case .shape(let shape):
                    shapes[shape] = NSNumber(value: value)
                case .pair(let left, let right):
                    shapes[left] = NSNumber(value: value)
                    shapes[right] = NSNumber(value: value)
                case .yaw, .pitch, .roll:
                    break
                }
            }
            return shapes
        }

        /// Pitch, yaw and roll in radians for neck exercises.
        static func headAngles(for pose: Pose) -> SIMD3<Float> {
            var angles = SIMD3<Float>.zero
            let toRadians = Float.pi / 180
            for requirement in pose.requirements where requirement.mode == .above {
                let degrees = Float(requirement.target)
                switch requirement.signal {
                case .pitch: angles.x = degrees * toRadians
                case .yaw: angles.y = degrees * toRadians
                case .roll: angles.z = degrees * toRadians
                default: break
                }
            }
            return angles
        }
    }
}
