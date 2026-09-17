import SwiftUI
import SceneKit

/// Rotatable color 3D face: the scan's mesh wrapped in the camera photo.
struct TexturedFaceView: UIViewRepresentable {
    let texture: FaceTexture
    let image: UIImage

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.target = SCNVector3Zero

        let (scene, cameraNode) = makeScene()
        view.scene = scene
        view.pointOfView = cameraNode
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    private func makeScene() -> (SCNScene, SCNNode) {
        let scene = SCNScene()
        let count = texture.vertexCount

        // Centre the face on the origin so it orbits around its own middle.
        var centre = SIMD3<Float>.zero
        for i in 0..<count {
            centre += SIMD3<Float>(texture.vertices[i * 3], texture.vertices[i * 3 + 1], texture.vertices[i * 3 + 2])
        }
        centre /= Float(Swift.max(count, 1))

        var positions: [SCNVector3] = []
        var coordinates: [CGPoint] = []
        positions.reserveCapacity(count)
        coordinates.reserveCapacity(count)
        for i in 0..<count {
            positions.append(SCNVector3(texture.vertices[i * 3] - centre.x,
                                        texture.vertices[i * 3 + 1] - centre.y,
                                        texture.vertices[i * 3 + 2] - centre.z))
            let u = i * 2 + 1 < texture.uvs.count ? texture.uvs[i * 2] : 0
            let v = i * 2 + 1 < texture.uvs.count ? texture.uvs[i * 2 + 1] : 0
            coordinates.append(CGPoint(x: CGFloat(u), y: CGFloat(v)))
        }

        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(textureCoordinates: coordinates)],
            elements: [SCNGeometryElement(indices: texture.indices, primitiveType: .triangles)]
        )
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.materials = [material]

        let faceNode = SCNNode(geometry: geometry)
        faceNode.eulerAngles.y = 0.35   // start at a three-quarter view so the depth is obvious
        scene.rootNode.addChildNode(faceNode)

        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 10
        camera.fieldOfView = 35
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 0.42)
        scene.rootNode.addChildNode(cameraNode)

        return (scene, cameraNode)
    }
}
