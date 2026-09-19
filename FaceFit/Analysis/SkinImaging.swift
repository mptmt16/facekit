import CoreGraphics
import UIKit

/// Image-processing helpers behind the skin scan: pixel access, blur, zone masks,
/// spot and line detection, and the zoomed crops with findings circled.
extension SkinAnalyzer {
    static func makePixels(from image: CGImage, maxSide: Int) -> Pixels? {
        let longest = Swift.max(image.width, image.height)
        let scale = longest > maxSide ? CGFloat(maxSide) / CGFloat(longest) : 1
        let width = Int((CGFloat(image.width) * scale).rounded())
        let height = Int((CGFloat(image.height) * scale).rounded())
        guard width > 60, height > 60 else { return nil }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drew = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        var luma = [Float](repeating: 0, count: width * height)
        var redness = [Float](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Float(rgba[i * 4]) / 255
            let g = Float(rgba[i * 4 + 1]) / 255
            let b = Float(rgba[i * 4 + 2]) / 255
            luma[i] = 0.299 * r + 0.587 * g + 0.114 * b
            redness[i] = r - (g + b) / 2
        }
        return Pixels(width: width, height: height, luma: luma, redness: redness)
    }

    /// Separable box blur, used as the "local average" the skin is compared against.
    static func boxBlur(_ values: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        guard radius > 0, values.count == width * height else { return values }
        var horizontal = [Float](repeating: 0, count: values.count)
        for y in 0..<height {
            var sum: Float = 0
            let row = y * width
            for x in -radius...radius {
                sum += values[row + Swift.min(Swift.max(x, 0), width - 1)]
            }
            for x in 0..<width {
                horizontal[row + x] = sum / Float(radius * 2 + 1)
                let outgoing = values[row + Swift.min(Swift.max(x - radius, 0), width - 1)]
                let incoming = values[row + Swift.min(Swift.max(x + radius + 1, 0), width - 1)]
                sum += incoming - outgoing
            }
        }

        var result = [Float](repeating: 0, count: values.count)
        for x in 0..<width {
            var sum: Float = 0
            for y in -radius...radius {
                sum += horizontal[Swift.min(Swift.max(y, 0), height - 1) * width + x]
            }
            for y in 0..<height {
                result[y * width + x] = sum / Float(radius * 2 + 1)
                let outgoing = horizontal[Swift.min(Swift.max(y - radius, 0), height - 1) * width + x]
                let incoming = horizontal[Swift.min(Swift.max(y + radius + 1, 0), height - 1) * width + x]
                sum += incoming - outgoing
            }
        }
        return result
    }

    // MARK: - Zone masks

    static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }

        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        guard lower.count > 1, upper.count > 1 else { return points }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    static func fill(hull: [CGPoint], into mask: inout [UInt8], value: UInt8, width: Int, height: Int) {
        guard hull.count >= 3 else { return }
        let minX = Swift.max(0, Int((hull.map(\.x).min() ?? 0).rounded(.down)))
        let maxX = Swift.min(width - 1, Int((hull.map(\.x).max() ?? 0).rounded(.up)))
        let minY = Swift.max(0, Int((hull.map(\.y).min() ?? 0).rounded(.down)))
        let maxY = Swift.min(height - 1, Int((hull.map(\.y).max() ?? 0).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            for x in minX...maxX where contains(hull: hull, point: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) {
                mask[y * width + x] = value
            }
        }
    }

    static func contains(hull: [CGPoint], point: CGPoint) -> Bool {
        var sawPositive = false
        var sawNegative = false
        for index in hull.indices {
            let a = hull[index]
            let b = hull[(index + 1) % hull.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if cross > 0 { sawPositive = true }
            if cross < 0 { sawNegative = true }
            if sawPositive && sawNegative { return false }
        }
        return true
    }

    // MARK: - Spots

    static func detectSpots(pixels: Pixels, blurredLuma: [Float], blurredRedness: [Float],
                            mask: [UInt8], zoneOrder: [SkinZone], width: Int, height: Int) -> [SkinFinding] {
        let minimumDarkness: Float = 0.035
        var candidates: [(index: Int, strength: Float)] = []
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) {
                let index = y * width + x
                guard mask[index] > 0 else { continue }
                let local = blurredLuma[index]
                // Very dark neighbourhoods are hair, nostrils or shadow, not skin.
                guard local > 0.18 else { continue }
                let darkness = local - pixels.luma[index]
                guard darkness > minimumDarkness, darkness < 0.30 else { continue }
                candidates.append((index, darkness))
            }
        }
        guard !candidates.isEmpty else { return [] }
        candidates.sort { $0.strength > $1.strength }

        let separation = Swift.max(4, width / 60)
        var taken = [Bool](repeating: false, count: width * height)
        var findings: [SkinFinding] = []
        for candidate in candidates {
            guard findings.count < 60 else { break }
            guard !taken[candidate.index] else { continue }
            let x = candidate.index % width
            let y = candidate.index / width

            var isPeak = true
            for dy in -2...2 {
                for dx in -2...2 {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let neighbour = ny * width + nx
                    if blurredLuma[neighbour] - pixels.luma[neighbour] > candidate.strength + 0.0005 {
                        isPeak = false
                    }
                }
                if !isPeak { break }
            }
            guard isPeak else { continue }

            for dy in -separation...separation {
                for dx in -separation...separation {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    if dx * dx + dy * dy <= separation * separation {
                        taken[ny * width + nx] = true
                    }
                }
            }

            let rednessDelta = pixels.redness[candidate.index] - blurredRedness[candidate.index]
            let zoneSlot = Int(mask[candidate.index]) - 1
            guard zoneSlot >= 0, zoneSlot < zoneOrder.count else { continue }
            let spread = Swift.min(2.2, candidate.strength / minimumDarkness)
            findings.append(SkinFinding(
                id: "\(x)-\(y)",
                kind: rednessDelta > 0.012 ? .blemish : .darkSpot,
                zone: zoneOrder[zoneSlot],
                x: Double(x) / Double(width),
                y: Double(y) / Double(height),
                radius: Double(Float(separation) * spread) / Double(width)
            ))
        }
        return findings
    }

    // MARK: - Fine lines

    static func detectLines(pixels: Pixels, blurredLuma: [Float], mask: [UInt8],
                            zoneCount: Int, width: Int, height: Int) -> [Int] {
        var counts = [Int](repeating: 0, count: zoneCount)
        var sum: Float = 0
        var squares: Float = 0
        var samples: Float = 0
        for index in 0..<(width * height) where mask[index] > 0 {
            let detail = blurredLuma[index] - pixels.luma[index]
            sum += detail
            squares += detail * detail
            samples += 1
        }
        guard samples > 500 else { return counts }
        let mean = sum / samples
        let deviation = Swift.max(0.0005, (squares / samples - mean * mean)).squareRoot()
        let threshold = mean + 1.8 * deviation

        var ridge = [Bool](repeating: false, count: width * height)
        for index in 0..<(width * height) where mask[index] > 0 {
            ridge[index] = (blurredLuma[index] - pixels.luma[index]) > threshold
        }

        var visited = [Bool](repeating: false, count: width * height)
        var stack: [Int] = []
        let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        for start in 0..<(width * height) where ridge[start] && !visited[start] {
            visited[start] = true
            stack.removeAll(keepingCapacity: true)
            stack.append(start)
            var minX = width, maxX = 0, minY = height, maxY = 0, size = 0
            var votes: [Int: Int] = [:]

            while let current = stack.popLast() {
                size += 1
                let x = current % width
                let y = current / width
                minX = Swift.min(minX, x)
                maxX = Swift.max(maxX, x)
                minY = Swift.min(minY, y)
                maxY = Swift.max(maxY, y)
                votes[Int(mask[current]), default: 0] += 1
                for (dx, dy) in neighbours {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let neighbour = ny * width + nx
                    if ridge[neighbour], !visited[neighbour] {
                        visited[neighbour] = true
                        stack.append(neighbour)
                    }
                }
            }

            let boxWidth = maxX - minX + 1
            let boxHeight = maxY - minY + 1
            let longSide = Swift.max(boxWidth, boxHeight)
            let shortSide = Swift.max(1, Swift.min(boxWidth, boxHeight))
            // A line is long, thin and made of enough pixels to not be noise.
            guard size >= 12, longSide >= width / 40, longSide >= shortSide * 3 else { continue }
            if let slot = votes.max(by: { $0.value < $1.value })?.key, slot > 0, slot - 1 < counts.count {
                counts[slot - 1] += 1
            }
        }
        return counts
    }

    // MARK: - Crops

    static func makeCrop(image: UIImage, normalizedRect: CGRect, findings: [SkinFinding]) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        var rect = CGRect(x: normalizedRect.minX * imageWidth, y: normalizedRect.minY * imageHeight,
                          width: normalizedRect.width * imageWidth, height: normalizedRect.height * imageHeight)
        rect = rect.insetBy(dx: -rect.width * 0.12, dy: -rect.height * 0.12)
            .intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        guard rect.width > 24, rect.height > 24, let cropped = cgImage.cropping(to: rect) else { return nil }

        let target = CGSize(width: 320, height: Swift.max(120, 320 * rect.height / rect.width))
        let scaleX = target.width / rect.width
        let scaleY = target.height / rect.height
        let renderer = UIGraphicsImageRenderer(size: target)
        let annotated = renderer.image { context in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: target))
            context.cgContext.setLineWidth(2.5)
            for finding in findings {
                let centreX = CGFloat(finding.x) * imageWidth - rect.minX
                let centreY = CGFloat(finding.y) * imageHeight - rect.minY
                let radius = Swift.max(CGFloat(6), CGFloat(finding.radius) * imageWidth * 1.4)
                let circle = CGRect(x: (centreX - radius) * scaleX, y: (centreY - radius) * scaleY,
                                    width: radius * 2 * scaleX, height: radius * 2 * scaleY)
                let colour = finding.kind == .blemish
                    ? UIColor(red: 1, green: 0.35, blue: 0.45, alpha: 0.95)
                    : UIColor(red: 1, green: 0.78, blue: 0.30, alpha: 0.95)
                context.cgContext.setStrokeColor(colour.cgColor)
                context.cgContext.strokeEllipse(in: circle)
            }
        }
        return annotated.jpegData(compressionQuality: 0.8)
    }
}
