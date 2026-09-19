import SwiftUI

/// Lifestyle details the user can enter; they shape the daily tips.
struct UserProfile {
    var name: String
    var age: Int
    var waterGlasses: Int
    var sleepHours: Double
    var screenHours: Double

    var isEmpty: Bool { name.isEmpty && age == 0 }
}

enum ProfileKey {
    static let name = "profileName"
    static let age = "profileAge"
    static let water = "profileWater"
    static let sleep = "profileSleep"
    static let screen = "profileScreen"
}

/// A short, dated piece of advice for the Today screen.
struct DailyTip: Identifiable {
    let id: String
    let text: String
    let symbol: String
}

enum DailyTips {
    /// Picks one tip for the given day, so it stays the same all day but rotates.
    static func tip(for date: Date, profile: UserProfile, scan: FaceScan?, streak: Int) -> DailyTip {
        var pool: [DailyTip] = []

        if profile.waterGlasses > 0 && profile.waterGlasses < 8 {
            pool.append(DailyTip(id: "water",
                                 text: "You're drinking about \(profile.waterGlasses) glasses of water a day. Working up to 8 keeps skin plumper and helps under-eye shadows.",
                                 symbol: "drop.fill"))
        }
        if profile.sleepHours > 0 && profile.sleepHours < 7 {
            pool.append(DailyTip(id: "sleep",
                                 text: "At \(profile.sleepHours.formatted()) hours, sleep is your easiest win. Most under-eye puffiness improves with an extra hour.",
                                 symbol: "bed.double.fill"))
        }
        if profile.screenHours >= 5 {
            pool.append(DailyTip(id: "screen",
                                 text: "With \(profile.screenHours.formatted()) hours of screen time, use the 20-20-20 rule: every 20 minutes, look 6 metres away for 20 seconds.",
                                 symbol: "iphone"))
        }
        if let scan {
            if let skin = scan.skin, skin.overall < 70 {
                pool.append(DailyTip(id: "skin",
                                     text: "Your skin score was \(Int(skin.overall.rounded())). Daily sunscreen is the single highest-impact habit for tone and dark spots.",
                                     symbol: "sun.max.fill"))
            }
            if scan.relaxationScore < 70 {
                pool.append(DailyTip(id: "tension",
                                     text: "Your resting face carries tension. Try one round of Soft Face before bed and let your jaw hang loose.",
                                     symbol: "leaf.fill"))
            }
            if scan.symmetryScore < 75 {
                pool.append(DailyTip(id: "symmetry",
                                     text: "Train your weaker side on its own with Side Smile and Wink Control — balance improves faster than overall strength.",
                                     symbol: "circle.lefthalf.filled"))
            }
        }
        if streak == 0 {
            pool.append(DailyTip(id: "restart",
                                 text: "Short and regular beats long and rare. Even three minutes today restarts your streak.",
                                 symbol: "flame.fill"))
        } else if streak >= 3 {
            pool.append(DailyTip(id: "streak",
                                 text: "\(streak) days in a row. Facial muscles respond to frequency, so keep the streak before adding more reps.",
                                 symbol: "flame.fill"))
        }

        pool.append(contentsOf: [
            DailyTip(id: "posture",
                     text: "Check your posture while you train. A dropped chin shortens the neck muscles you're trying to lengthen.",
                     symbol: "figure.stand"),
            DailyTip(id: "slow",
                     text: "Slow reps beat fast ones. Take two seconds into the movement and two seconds out.",
                     symbol: "tortoise.fill"),
            DailyTip(id: "mirror",
                     text: "Use Face Lab for a minute to see which muscles fire when you smile — awareness makes the exercises work better.",
                     symbol: "waveform"),
            DailyTip(id: "relax",
                     text: "Between reps, let your face go completely slack for a few seconds. The release is part of the training.",
                     symbol: "wind"),
            DailyTip(id: "consistency",
                     text: "Scan once a week in the same light. Day-to-day changes are mostly lighting, not your face.",
                     symbol: "calendar"),
        ])

        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[day % pool.count]
    }
}
