# FaceFit — Face Exercise & Analyzer for iPhone

FaceFit uses the iPhone's **TrueDepth (Face ID) front camera** to coach facial exercises in real time and to analyze your face in 3D. It uses ARKit face tracking: 52 muscle-movement signals ("blend shapes"), a 1,220-point face mesh measured in real millimetres, and head pose.

Everything runs on the device. No images or face data leave the phone.

## Features

**Exercises (18 + a daily routine)**
- Guided exercises for cheeks and smile, lips, jaw and tongue, brows, eyes and nose, neck, and relaxation
- Live activation ring that shows how close you are to the target, plus a hold timer, rep counter and left/right symmetry
- A hold only counts while the right muscles are working. Between reps you have to relax, so every rep is a full contraction
- Voice coach and haptics, so you can follow along with your eyes closed or your head turned
- Multi-move reps (Kiss & Smile, Jaw Slide, Wink Control) and "stay below" goals (Soft Face relaxation)
- Neck exercises measure yaw, pitch and roll against a neutral pose captured during the countdown
- Gentle, Standard and Intense difficulty settings

**3D Face Scan (about 40 s, 8 guided steps)**
- **Structural symmetry:** averages the neutral face mesh, mirrors it across the midline and measures each point's difference in mm. You get a drag-to-rotate 3D heat map.
- **Expression symmetry and range:** peak left and right movement for smile, brows, eye closure and nose, plus range for cheek puff, pucker and jaw opening
- **Resting tension:** finds muscles that stay active when you think you're relaxed (brow furrow, squinting, lip pressing, a jaw pushed forward and more), with advice for each
- **Measurements:** eye distance, face mesh width and height
- An overall Face Score and recommended exercises for your weakest areas

**Face Score**
- Weighted 0–100 score from four pillars: **Symmetry** (30%), **Mobility** (25%), **Control** (20%, from a left and right wink test) and **Relaxation** (25%)
- Levels (Getting started → Developing → Fit → Strong → Elite) with points needed to reach the next level
- A radar chart that overlays your previous scan, the change in each pillar, and a "focus next" hint
- A shareable score card image that contains scores only, never face data

**Face Analysis & Improvement Plan**
- Scores for each area (0–100), each with an insight into what's holding it back:
  - **Jawline:** jaw range and a relaxed jaw position
  - **Cheeks:** smile lift, balance and cheek strength
  - **Lips & Mouth:** pucker strength, relaxed lips and mouth corners
  - **Eye Area:** eyelid strength, wink control and squinting
  - **Forehead & Brows:** brow lift, balance and frown tension
  - **Symmetry:** balance of movement and of the 3D structure
- **Your improvement plan:** picks your 3 weakest areas (goals you choose get extra priority), assigns 2 targeted exercises each plus a relaxation cool-down, and runs with one tap. The Today tab shows it as "Your plan for today". It works from goals alone before your first scan.
- **Scientific face type:** the Martin–Saller **facial index**, face height (nasion–menton) ÷ bizygomatic width × 100, which is the classification used in physical anthropology:

  | Facial index | Class | Meaning |
  |---|---|---|
  | below 80 | Hypereuryprosopic | very broad, short face |
  | 80–84.9 | Euryprosopic | broad face |
  | 85–89.9 | Mesoprosopic | medium face |
  | 90–94.9 | Leptoprosopic | long, narrow face |
  | 95 and above | Hyperleptoprosopic | very long, narrow face |

  It also gives the **upper facial index** (nasion–stomion, from euryene to leptene). Landmarks are found automatically on the 3D mesh: nasion is the deepest point of the midline profile between the brows, menton is the lowest point of the chin, stomion is the centre of the mouth opening, and bizygomatic width is the widest point between nose-tip and eye level. Other 3D measurements, in mm, are jaw, forehead and mouth width, eye width, the gap between your eyes, and nose projection. Labels like oval, heart or square are fashion terms with no scientific definition, so the app doesn't use them.
- **Color 3D face:** during the relaxed step of the scan, one camera frame is projected onto the mesh (like Apple's video-textured face sample), and the eye and mouth openings are capped. You get a real-color 3D model to rotate and zoom, with a switch to the symmetry heat map. It is stored only on the device, and you can turn it off in Settings.

**Game progression**
- **XP** from every rep (5 each), finished exercises (+20), full-target form (+10), scans (80), eye tests (40) and Face Challenge games
- **Levels** with rank names (Rookie → Trainee → Regular → Athlete → Pro → Master); level *n* needs `150 x (n-1)^1.5` XP
- **Exercises unlock as you level up.** You start with 4 (Smile Lift, Brow Raise, Jaw Opener, Soft Face) and the rest arrive up to level 9; programs unlock between levels 2 and 7. Locked exercises stay out of your plan and the daily workout.
- **Journey map** showing every level, what it unlocks and where you are
- **Daily quests:** three a day from a pool (reps, mixed exercises, XP, perfect form, scan, eye test, per-area goals), worth 40–80 bonus XP, with progress read from your history
- **Mastery stars** per exercise at 20, 60 and 150 total reps
- **Daily XP goal** of 150, plus level-up and unlock celebrations on the session summary

**Skin Analysis (on-device)**
- Splits the TrueDepth mesh into six zones (forehead, nose, both cheeks, under-eye, chin) and maps them onto the scan photo, excluding eyes, brows and lips
- Counts **blemishes** (reddish) and **dark spots** (not red) as local-contrast peaks, skipping very dark areas so hair and shadow don't count, and counts **fine lines** as elongated ridge components
- Scores clarity, texture, tone evenness, calmness, shine, fine lines and under-eye brightness, plus a score per zone
- Zoomed crops with each finding circled, a zone map and plain-language tips
- Unlike cloud-based competitors, no photo ever leaves the device

**Training experience**
- **3D demo for every exercise**, built from ARKit's own face model driven by the same blend shapes the app measures, so there is no stock footage and the demo always matches the target
- **Form %** and a live bar per muscle during a session: bolt for muscles that must work, leaf for muscles that must stay relaxed
- Beginner / Intermediate / Advanced levels, search across names and muscles, and swipe-to-save favourites

**Before & after:** two scans side by side with the photos, plus the change in Face Score, each pillar, skin score, spot counts and every area.

**You tab:** name, age, water, sleep and screen time (stored on device), streak and totals, scan history, achievements, before & after, and settings. A **tip of the day** on the Today screen reacts to those habits and your latest scan.

**Face Challenge:** a 60-second game where you copy as many expressions as you can (grin, wink, tongue out, head turns and more), with speed and streak bonuses and a saved high score.

**Eye Comfort Test:** read for one minute while TrueDepth counts full and incomplete blinks and measures your longest stare. You get an eye comfort score and screen-habit tips.

**Programs:** themed routines (Jawline & Neck, Smile Symmetry, Bright Eyes, Stress Release, Full Face Burn), plus the daily workout.

**Daily reminder:** an optional notification at a time you choose.

**Achievements:** 14 badges for streaks, reps, scores, the challenge and eye tests.

**Progress:** day streaks, weekly and 30-day activity charts, score trends across scans, a breakdown by muscle group and session history (SwiftData).

**Face Lab:** a live readout of all 52 blend shapes, head angles, eye distance and left/right balance.

## Requirements

- An iPhone with Face ID / TrueDepth (iPhone X or newer, not an SE) running **iOS 17+**
- **Either** a GitHub account (the app is built on GitHub's cloud Macs, and you install it from Windows) **or** a Mac with **Xcode 16 or later**

## Install without a Mac (Windows)

**1. Build in the cloud (free)**
1. Create a repository on GitHub and push this `FaceFit` folder to it, so `FaceFit.xcodeproj` sits at the repository root. A public repo gets free macOS build minutes; a private repo uses your monthly free allowance.
2. Each push to `main` runs **Actions → Build iOS app** (about 5–10 min). You can also start it by hand with **Run workflow**.
3. When the run is green, download **FaceFit-unsigned-ipa** from the run's *Artifacts* section and unzip it to get `FaceFit-unsigned.ipa`.
4. If the run is red, the run summary lists the compile errors with file and line.

**2. Install on your iPhone with Sideloadly**
1. On Windows, install **Sideloadly** from sideloadly.io, plus the Apple drivers its download page asks for (iTunes / iCloud from apple.com).
2. Connect your iPhone by USB, unlock it and tap **Trust**.
3. Drag `FaceFit-unsigned.ipa` into Sideloadly, enter an Apple ID, then click **Start**. A secondary Apple ID is fine and is the safer choice.
4. On the iPhone:
   - Turn on **Settings → Privacy & Security → Developer Mode**. The phone restarts.
   - Trust your Apple ID under **Settings → General → VPN & Device Management**.
5. Open FaceFit and allow camera access.

With a free Apple ID the app stops launching after **7 days**. To refresh it, sideload the same IPA again (Sideloadly can also refresh it automatically over Wi-Fi). A paid Apple Developer account ($99/year) removes that limit and lets you ship through **TestFlight**, which you can also set up from Windows with a cloud build service.

## Run it on a Mac

1. Open `FaceFit.xcodeproj` in Xcode.
2. Select the **FaceFit** target → **Signing & Capabilities** → choose your **Team**. Change the bundle identifier (`com.yourname.FaceFit`) to something unique.
3. Plug in your iPhone, select it as the run destination and press **Run**.
4. On first launch, allow camera access.

**Simulator / non-TrueDepth devices:** the app runs in **demo mode** with a simulated, animated face. You can walk through every screen, exercise and scan. The 3D mesh heat map needs real TrueDepth data.

## Check on a real device

Open **Analyze → Face Lab** and test these:

| Do this | Expect |
|---|---|
| Close only your **left** eye | "Blink L" rises. If "Blink R" rises instead, see *Left/right* below. |
| Smile | Smile L/R both rise, balance shown |
| Turn head to your left | Yaw goes positive |
| Chin up | Pitch goes positive |
| Tilt head to left shoulder | Roll goes positive |
| Look straight | Eye distance of about 55–70 mm |

**Left/right:** ARKit names blend shapes from the face's own point of view. If you ever see them reversed on a device, swap the cues in the one-sided exercises (`side-smile`, `wink-control`) in `ExerciseLibrary.swift`.

## Project structure

```
FaceFit/
├── .github/            Cloud build (GitHub Actions on macOS) → unsigned .ipa
├── FaceFit.xcodeproj
└── FaceFit/
    ├── App/            App entry, tab root, onboarding, settings keys
    ├── Tracking/       ARKit session → FaceSample, head pose math, mesh math, camera view
    ├── Exercises/      Exercise model + signal requirements, library, rep state machine
    ├── Analysis/       Scan steps, tension checks, scan engine & scoring
    ├── Data/           SwiftData models (ExerciseSession, FaceScan)
    ├── Services/       Voice coach + haptics
    ├── Views/          Today, Exercises, Analyze (scan, results, heat map, Face Lab), Progress, Settings
    └── Assets.xcassets App icon, accent colour
```

### How it works

- **`FaceTracker`** runs `ARFaceTrackingConfiguration` and processes frames at 30 Hz into a `FaceSample` (blend shapes, head pose, eye positions and, during scans, mesh vertices). If there's no TrueDepth camera, it simulates a face instead.
- **Head pose** (`HeadPose.from`) expresses the direction to the camera and gravity in the face's own coordinate frame, so the angles don't depend on sensor orientation.
- **An exercise** is a list of `Pose`s. Each pose has `Requirement`s such as `.atLeast(.pair(.mouthSmileLeft, .mouthSmileRight), 0.55)` or `.atMost(.shape(.jawForward), 0.15)`. `ExerciseEngine` runs countdown → hold (with a 15% dip tolerance) → rep → rest (must relax) → finished.
- **The mesh symmetry** step pairs each vertex with its mirror partner. It builds the pairs from ARKit's neutral reference face, re-centres the mirror plane, then measures per-vertex distance on a mesh averaged over the 5-second neutral step, skipping frames where you blink.

### Add an exercise

Add an entry to `ExerciseLibrary.all`:

```swift
Exercise(
    id: "cheek-lift", name: "Cheek Lift", category: .cheeks, symbol: "face.smiling",
    summary: "…", muscles: "…", steps: ["…"],
    poses: [Pose(cue: "Squint your cheeks up", requirements: [
        .atLeast(.pair(.cheekSquintLeft, .cheekSquintRight), 0.4),
    ])],
    holdSeconds: 3, reps: 8
)
```

Use Face Lab to see what values your face actually reaches before you pick thresholds.

## Tuning notes

- Thresholds are starting points. Blend-shape ranges vary from person to person, so use the Difficulty setting or edit targets in `ExerciseLibrary.swift`.
- Structural symmetry maps to a score as `100 − (mm − 1) × 15` in `FaceScanEngine.computeOutcome`. Adjust it once you've seen real scans.
- The live mesh overlay uses SceneKit (`ARSCNFaceGeometry`). SceneKit is soft-deprecated in the latest SDKs but still works, so you may see deprecation warnings.

## Disclaimer

FaceFit is a wellness and training tool, **not a medical device**. It doesn't diagnose or treat any condition. People with facial paralysis, TMJ disorders or pain should consult a clinician before doing facial exercises.
