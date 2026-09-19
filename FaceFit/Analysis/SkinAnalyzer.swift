import CoreGraphics
import UIKit
import simd

/// On-device skin analysis of the scan photo: spots, fine lines, tone and texture,
/// scored per face zone. Nothing is uploaded.
enum SkinAnalyzer {
    struct Pixels {
        let width: Int
        let height: Int
        var luma: [Float]
        var redness: [Float]
    }

    struct ZoneStats {
        var pixels = 0
        var lumaSum: Float = 0
        var textureSum: Float = 0
        var textureSquares: Float = 0
        var rednessSum: Float = 0
        var rednessSquares: Float = 0
        var shine = 0
        var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
    }

    static func analyze(jpeg: Data, texture: FaceTexture) -> SkinReport? {
        guard let uiImage = UIImage(data: jpeg), let cgImage = uiImage.cgImage,
              let pixels = makePixels(from: cgImage, maxSide: 720) else { return nil }

        let baseVertexCount = Swift.min(texture.baseVertexCount ?? texture.vertexCount, texture.vertexCount)
        let baseIndexCount = Swift.min(texture.baseIndexCount ?? texture.indices.count, texture.indices.count)
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(baseVertexCount)
        for i in 0..<baseVertexCount {
            vertices.append(SIMD3<Float>(texture.vertices[i * 3], texture.vertices[i * 3 + 1], texture.vertices[i * 3 + 2]))
        }
        guard let layout = FaceZones.layout(vertices: vertices, indices: Array(texture.indices.prefix(baseIndexCount))) else {
            return nil
        }

        let width = pixels.width
        let height = pixels.height
        let blurRadius = Swift.max(4, width / 40)
        let blurredLuma = boxBlur(pixels.luma, width: width, height: height, radius: blurRadius)
        let blurredRedness = boxBlur(pixels.redness, width: width, height: height, radius: blurRadius)

        // Rasterise each zone into a mask.
        var mask = [UInt8](repeating: 0, count: width * height)
        var zoneOrder: [SkinZone] = []
        for zone in SkinZone.allCases {
            guard let members = layout.zones[zone], members.count >= 8 else { continue }
            let points = members.compactMap { index -> CGPoint? in
                guard index * 2 + 1 < texture.uvs.count else { return nil }
                return CGPoint(x: CGFloat(texture.uvs[index * 2]) * CGFloat(width),
                               y: CGFloat(texture.uvs[index * 2 + 1]) * CGFloat(height))
            }
            let hull = convexHull(points)
            guard hull.count >= 3 else { continue }
            zoneOrder.append(zone)
            fill(hull: hull, into: &mask, value: UInt8(zoneOrder.count), width: width, height: height)
        }
        guard !zoneOrder.isEmpty else { return nil }

        // Zone statistics.
        var stats = [ZoneStats](repeating: ZoneStats(), count: zoneOrder.count)
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let zoneValue = mask[index]
                guard zoneValue > 0 else { continue }
                let slot = Int(zoneValue) - 1
                let detail = pixels.luma[index] - blurredLuma[index]
                stats[slot].pixels += 1
                stats[slot].lumaSum += pixels.luma[index]
                stats[slot].textureSum += detail
                stats[slot].textureSquares += detail * detail
                stats[slot].rednessSum += pixels.redness[index]
                stats[slot].rednessSquares += pixels.redness[index] * pixels.redness[index]
                if pixels.luma[index] > 0.82 { stats[slot].shine += 1 }
                stats[slot].minX = Swift.min(stats[slot].minX, x)
                stats[slot].maxX = Swift.max(stats[slot].maxX, x)
                stats[slot].minY = Swift.min(stats[slot].minY, y)
                stats[slot].maxY = Swift.max(stats[slot].maxY, y)
            }
        }

        let findings = detectSpots(pixels: pixels, blurredLuma: blurredLuma, blurredRedness: blurredRedness,
                                   mask: mask, zoneOrder: zoneOrder, width: width, height: height)
        let lines = detectLines(pixels: pixels, blurredLuma: blurredLuma, mask: mask,
                                zoneCount: zoneOrder.count, width: width, height: height)

        // Per-zone scores.
        var zoneResults: [SkinZoneResult] = []
        var underEyeLuma: Float?
        var cheekLuma: Float?
        for (slot, zone) in zoneOrder.enumerated() {
            let stat = stats[slot]
            guard stat.pixels > 200 else { continue }
            let count = Float(stat.pixels)
            let meanLuma = stat.lumaSum / count
            let textureStd = standardDeviation(sum: stat.textureSum, squares: stat.textureSquares, count: count)
            let rednessStd = standardDeviation(sum: stat.rednessSum, squares: stat.rednessSquares, count: count)
            let meanRedness = stat.rednessSum / count
            let shineRatio = Float(stat.shine) / count

            if zone == .underEyes { underEyeLuma = meanLuma }
            if zone == .leftCheek || zone == .rightCheek {
                cheekLuma = cheekLuma.map { ($0 + meanLuma) / 2 } ?? meanLuma
            }

            let zoneFindings = findings.filter { $0.zone == zone }
            let blemishes = zoneFindings.filter { $0.kind == .blemish }.count
            let darkSpots = zoneFindings.filter { $0.kind == .darkSpot }.count
            let lineCount = lines[slot]

            var score = 100.0
            score -= Swift.min(34, Double(blemishes) * 6 + Double(darkSpots) * 3)
            score -= Swift.min(24, Double(textureStd) * 620)
            score -= Swift.min(18, Double(rednessStd) * 420)
            score -= Swift.min(12, Swift.max(0, Double(meanRedness) - 0.07) * 260)
            score -= Swift.min(10, Double(shineRatio) * 90)
            score -= Swift.min(10, Double(lineCount) * 1.2)
            score = Swift.min(100, Swift.max(5, score))

            zoneResults.append(SkinZoneResult(
                zone: zone,
                score: score,
                summary: summary(blemishes: blemishes, darkSpots: darkSpots, lines: lineCount,
                                 textureStd: textureStd, redness: meanRedness, score: score),
                blemishes: blemishes,
                darkSpots: darkSpots,
                lines: lineCount,
                cropJPEG: nil
            ))
        }
        guard !zoneResults.isEmpty else { return nil }

        // Crops for the zones with the most to show.
        let cropZones = zoneResults
            .filter { $0.blemishes + $0.darkSpots > 0 }
            .sorted { ($0.blemishes + $0.darkSpots) > ($1.blemishes + $1.darkSpots) }
            .prefix(2)
            .map(\.zone)
        for zone in cropZones {
            guard let slot = zoneOrder.firstIndex(of: zone), let position = zoneResults.firstIndex(where: { $0.zone == zone }) else { continue }
            let stat = stats[slot]
            guard stat.pixels > 200, stat.maxX > stat.minX else { continue }
            let rect = CGRect(x: CGFloat(stat.minX) / CGFloat(width), y: CGFloat(stat.minY) / CGFloat(height),
                              width: CGFloat(stat.maxX - stat.minX) / CGFloat(width),
                              height: CGFloat(stat.maxY - stat.minY) / CGFloat(height))
            zoneResults[position].cropJPEG = makeCrop(image: uiImage, normalizedRect: rect,
                                                      findings: findings.filter { $0.zone == zone })
        }

        let metrics = buildMetrics(stats: stats, zoneOrder: zoneOrder, findings: findings,
                                   lineTotal: lines.reduce(0, +), underEyeLuma: underEyeLuma, cheekLuma: cheekLuma)
        let overall = zoneResults.map(\.score).reduce(0, +) / Double(zoneResults.count)

        return SkinReport(overall: overall, zones: zoneResults, metrics: metrics,
                          findings: findings, lineCount: lines.reduce(0, +))
    }

    // MARK: - Metrics

    private static func buildMetrics(stats: [ZoneStats], zoneOrder: [SkinZone], findings: [SkinFinding],
                                     lineTotal: Int, underEyeLuma: Float?, cheekLuma: Float?) -> [SkinMetric] {
        var totalPixels: Float = 0
        var textureSum: Float = 0
        var textureSquares: Float = 0
        var rednessSum: Float = 0
        var rednessSquares: Float = 0
        var shine = 0
        for stat in stats {
            totalPixels += Float(stat.pixels)
            textureSum += stat.textureSum
            textureSquares += stat.textureSquares
            rednessSum += stat.rednessSum
            rednessSquares += stat.rednessSquares
            shine += stat.shine
        }
        guard totalPixels > 0 else { return [] }

        let textureStd = standardDeviation(sum: textureSum, squares: textureSquares, count: totalPixels)
        let rednessStd = standardDeviation(sum: rednessSum, squares: rednessSquares, count: totalPixels)
        let meanRedness = rednessSum / totalPixels
        let shineRatio = Float(shine) / totalPixels

        var metrics: [SkinMetric] = [
            SkinMetric(id: "clarity", title: "Clarity",
                       detail: "\(findings.count) spots found across your face",
                       score: Swift.min(100, Swift.max(5, 100 - Double(findings.count) * 4)),
                       symbol: "sparkles"),
            SkinMetric(id: "texture", title: "Texture",
                       detail: "Smoothness of the skin surface",
                       score: Swift.min(100, Swift.max(5, 100 - Double(textureStd) * 900)),
                       symbol: "circle.grid.3x3"),
            SkinMetric(id: "evenness", title: "Tone evenness",
                       detail: "How even your colour is across zones",
                       score: Swift.min(100, Swift.max(5, 100 - Double(rednessStd) * 700)),
                       symbol: "paintpalette"),
            SkinMetric(id: "redness", title: "Calmness",
                       detail: "Visible redness and irritation",
                       score: Swift.min(100, Swift.max(5, 100 - Swift.max(0, Double(meanRedness) - 0.06) * 480)),
                       symbol: "flame"),
            SkinMetric(id: "shine", title: "Shine balance",
                       detail: "Oil and shine in the T-zone",
                       score: Swift.min(100, Swift.max(5, 100 - Double(shineRatio) * 260)),
                       symbol: "sun.max"),
            SkinMetric(id: "lines", title: "Fine lines",
                       detail: "\(lineTotal) fine lines detected",
                       score: Swift.min(100, Swift.max(5, 100 - Double(lineTotal) * 2.0)),
                       symbol: "scribble"),
        ]

        if let underEyeLuma, let cheekLuma, cheekLuma > 0 {
            let ratio = Double(underEyeLuma / cheekLuma)
            metrics.append(SkinMetric(id: "underEye", title: "Under-eye brightness",
                                      detail: "Under-eye compared with your cheeks",
                                      score: Swift.min(100, Swift.max(5, 100 - Swift.max(0, 1 - ratio) * 420)),
                                      symbol: "eye"))
        }
        return metrics
    }

    private static func summary(blemishes: Int, darkSpots: Int, lines: Int,
                                textureStd: Float, redness: Float, score: Double) -> String {
        if blemishes >= 3 { return "\(blemishes) active blemishes" }
        if darkSpots >= 3 { return "\(darkSpots) darker spots" }
        if lines >= 6 { return "\(lines) fine lines" }
        if textureStd > 0.055 { return "Uneven texture" }
        if redness > 0.12 { return "Some redness" }
        return score >= 85 ? "Clear, even texture" : "Looking good overall"
    }

    private static func standardDeviation(sum: Float, squares: Float, count: Float) -> Float {
        guard count > 1 else { return 0 }
        let mean = sum / count
        return Swift.max(0, (squares / count - mean * mean)).squareRoot()
    }
}
