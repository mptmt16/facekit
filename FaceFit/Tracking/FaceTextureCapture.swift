import ARKit
import CoreImage
import UIKit

/// A color 3D face: mesh positions, texture coordinates into a JPEG photo, and triangles.
struct FaceTexture: Codable {
    /// Flattened x, y, z in metres (face-anchor space), including hole-cap centre vertices.
    var vertices: [Float]
    /// Flattened u, v per vertex in 0...1, origin at the top-left of the stored image.
    var uvs: [Float]
    var indices: [Int16]
    /// Counts before the eye and mouth openings were capped, so analysis can use the original mesh.
    var baseVertexCount: Int?
    var baseIndexCount: Int?

    var vertexCount: Int { vertices.count / 3 }
}

/// Builds a textured face mesh from one camera frame.
enum FaceTextureCapture {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    private static let maxImageSide: CGFloat = 1024

    static func make(frame: ARFrame, anchor: ARFaceAnchor) -> (texture: FaceTexture, jpeg: Data)? {
        let geometry = anchor.geometry
        let meshVertices = geometry.vertices
        let meshIndices = geometry.triangleIndices
        let imageSize = frame.camera.imageResolution
        guard !meshVertices.isEmpty, imageSize.width > 0, imageSize.height > 0 else { return nil }

        // Project each vertex exactly like Apple's video-textured face sample: into a portrait view,
        // then back through the inverse display transform (which undoes the front camera's mirroring)
        // into normalized coordinates of the captured image.
        let viewSize = CGSize(width: imageSize.height, height: imageSize.width)
        let viewToImage = frame.displayTransform(for: .portrait, viewportSize: viewSize).inverted()
        var pixels: [CGPoint] = []
        pixels.reserveCapacity(meshVertices.count)
        for vertex in meshVertices {
            let world = anchor.transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1)
            let viewPoint = frame.camera.projectPoint(SIMD3<Float>(world.x, world.y, world.z),
                                                      orientation: .portrait, viewportSize: viewSize)
            let normalized = CGPoint(x: viewPoint.x / viewSize.width, y: viewPoint.y / viewSize.height)
                .applying(viewToImage)
            pixels.append(CGPoint(x: normalized.x * imageSize.width, y: normalized.y * imageSize.height))
        }

        guard let minX = pixels.map(\.x).min(), let maxX = pixels.map(\.x).max(),
              let minY = pixels.map(\.y).min(), let maxY = pixels.map(\.y).max() else { return nil }
        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let crop = bounds
            .insetBy(dx: -bounds.width * 0.06, dy: -bounds.height * 0.06)
            .intersection(CGRect(origin: .zero, size: imageSize))
            .integral
        guard crop.width > 60, crop.height > 60 else { return nil }

        // Core Image has a bottom-left origin, so flip the crop vertically.
        let ciCrop = CGRect(x: crop.minX, y: imageSize.height - crop.maxY, width: crop.width, height: crop.height)
        let scale = Swift.min(1, maxImageSide / Swift.max(crop.width, crop.height))
        let output = CIImage(cvPixelBuffer: frame.capturedImage)
            .cropped(to: ciCrop)
            .transformed(by: CGAffineTransform(translationX: -ciCrop.minX, y: -ciCrop.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let outputRect = CGRect(x: 0, y: 0, width: (crop.width * scale).rounded(.down), height: (crop.height * scale).rounded(.down))
        guard let cgImage = context.createCGImage(output, from: outputRect),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85) else { return nil }

        var vertices: [Float] = []
        var uvs: [Float] = []
        vertices.reserveCapacity(meshVertices.count * 3 + 30)
        uvs.reserveCapacity(meshVertices.count * 2 + 20)
        for (vertex, pixel) in zip(meshVertices, pixels) {
            vertices += [vertex.x, vertex.y, vertex.z]
            uvs += [Float((pixel.x - crop.minX) / crop.width), Float((pixel.y - crop.minY) / crop.height)]
        }

        // Cap the eye and mouth openings so the photo shows real eyes and lips instead of holes.
        var indices = meshIndices
        let loops = MeshTopology.boundaryLoops(indices: meshIndices, vertexCount: meshVertices.count)
        let outline = loops.indices.max { width(of: loops[$0], in: meshVertices) < width(of: loops[$1], in: meshVertices) }
        for (loopIndex, loop) in loops.enumerated() where loopIndex != outline {
            let centreIndex = vertices.count / 3
            guard centreIndex < Int(Int16.max) else { break }
            var centre = SIMD3<Float>.zero
            var centreUV = SIMD2<Float>.zero
            for vertexIndex in loop {
                centre += meshVertices[vertexIndex]
                centreUV += SIMD2<Float>(uvs[vertexIndex * 2], uvs[vertexIndex * 2 + 1])
            }
            centre /= Float(loop.count)
            centreUV /= Float(loop.count)
            vertices += [centre.x, centre.y, centre.z]
            uvs += [centreUV.x, centreUV.y]
            for k in loop.indices {
                let a = loop[k]
                let b = loop[(k + 1) % loop.count]
                indices += [Int16(a), Int16(b), Int16(centreIndex)]
            }
        }

        let texture = FaceTexture(vertices: vertices, uvs: uvs, indices: indices,
                                  baseVertexCount: meshVertices.count, baseIndexCount: meshIndices.count)
        return (texture, jpeg)
    }

    private static func width(of loop: [Int], in vertices: [SIMD3<Float>]) -> Float {
        let xs = loop.map { vertices[$0].x }
        return (xs.max() ?? 0) - (xs.min() ?? 0)
    }
}
