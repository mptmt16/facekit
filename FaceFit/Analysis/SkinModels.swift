import SwiftUI

/// The face zones scored by the skin scan.
enum SkinZone: String, CaseIterable, Identifiable, Codable {
    case forehead, nose, leftCheek, rightCheek, underEyes, chin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forehead: "Forehead"
        case .nose: "Nose"
        case .leftCheek: "Left cheek"
        case .rightCheek: "Right cheek"
        case .underEyes: "Under-eye"
        case .chin: "Chin & jaw"
        }
    }

    var symbol: String {
        switch self {
        case .forehead: "arrow.up"
        case .nose: "nose"
        case .leftCheek: "face.smiling"
        case .rightCheek: "face.smiling.inverse"
        case .underEyes: "eye"
        case .chin: "mouth"
        }
    }

    /// Position on the schematic face map, in 0...1 of the oval.
    var mapPosition: CGPoint {
        switch self {
        case .forehead: CGPoint(x: 0.5, y: 0.18)
        case .underEyes: CGPoint(x: 0.5, y: 0.37)
        case .nose: CGPoint(x: 0.5, y: 0.5)
        case .leftCheek: CGPoint(x: 0.76, y: 0.52)
        case .rightCheek: CGPoint(x: 0.24, y: 0.52)
        case .chin: CGPoint(x: 0.5, y: 0.82)
        }
    }
}

/// One spot found on the skin.
struct SkinFinding: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case blemish, darkSpot

        var title: String { self == .blemish ? "Blemish" : "Dark spot" }
    }

    var id: String
    var kind: Kind
    var zone: SkinZone
    /// Position and radius in the scan photo, 0...1 of image width/height.
    var x: Double
    var y: Double
    var radius: Double
}

/// Score for one zone, with the finding counts behind it.
struct SkinZoneResult: Codable, Identifiable, Hashable {
    var zone: SkinZone
    var score: Double
    var summary: String
    var blemishes: Int
    var darkSpots: Int
    var lines: Int
    /// A zoomed JPEG crop with the findings circled.
    var cropJPEG: Data?

    var id: String { zone.rawValue }
}

/// A named skin measurement, 0–100.
struct SkinMetric: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var score: Double
    var symbol: String
}

/// Everything the skin scan produced.
struct SkinReport: Codable {
    var overall: Double
    var zones: [SkinZoneResult]
    var metrics: [SkinMetric]
    var findings: [SkinFinding]
    var lineCount: Int

    var blemishCount: Int { findings.filter { $0.kind == .blemish }.count }
    var darkSpotCount: Int { findings.filter { $0.kind == .darkSpot }.count }

    var weakestZone: SkinZoneResult? {
        zones.min { $0.score < $1.score }
    }

    /// Plain-language advice based on what was measured. Wellness guidance, not medical advice.
    var recommendations: [String] {
        var tips: [String] = []
        if blemishCount >= 5 {
            tips.append("We found \(blemishCount) active blemishes. A gentle cleanser twice a day and a non-comedogenic moisturiser help most people; see a dermatologist for persistent acne.")
        }
        if darkSpotCount >= 5 {
            tips.append("We found \(darkSpotCount) darker spots. Daily sunscreen is the single best way to stop pigmentation getting darker.")
        }
        if lineCount >= 15 {
            tips.append("Fine lines showed up mostly on the forehead and under the eyes. Moisturise, sleep well, and try the Soft Face relaxation exercise to stop holding tension there.")
        }
        for metric in metrics where metric.score < 60 {
            switch metric.id {
            case "evenness":
                tips.append("Your skin tone is a little uneven. Sunscreen and consistent hydration even it out over 6–8 weeks.")
            case "texture":
                tips.append("Texture looks rough in places. Avoid over-scrubbing; gentle exfoliation once or twice a week is enough.")
            case "redness":
                tips.append("There's visible redness. Cut back on very hot water and strong actives for a while, and use a fragrance-free moisturiser.")
            case "shine":
                tips.append("Your skin looks shiny in the T-zone. A lightweight gel moisturiser and blotting during the day help.")
            case "underEye":
                tips.append("Your under-eye area is darker than your cheeks. Sleep, hydration and the Eye Squeeze exercise all help; some under-eye shadow is simply anatomy.")
            default:
                break
            }
        }
        if tips.isEmpty {
            tips.append("Your skin scored well across the board. Keep your routine steady and scan again in a week.")
        }
        return tips
    }
}
