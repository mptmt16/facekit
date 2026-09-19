import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Query private var sessions: [ExerciseSession]
    @Query private var scans: [FaceScan]
    @Query private var blinkTests: [BlinkTest]
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0
    @AppStorage(SettingsKey.challengeGames) private var challengeGames = 0
    @AppStorage(SettingsKey.favouriteExercises) private var favouritesRaw = ""

    @State private var searchText = ""
    @State private var levelFilter: ExerciseLevel?
    @State private var routineRunning = false
    @State private var lockedExercise: Exercise?

    private var playerLevel: Int {
        Progression.level(forXP: Progression.totalXP(sessions: sessions, scans: scans, blinkTests: blinkTests,
                                                     challengeGames: challengeGames,
                                                     challengeHighScore: challengeHighScore))
    }

    private var favourites: Set<String> {
        Set(favouritesRaw.split(separator: ",").map(String.init))
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty || levelFilter != nil
    }

    private func matches(_ exercise: Exercise) -> Bool {
        if let levelFilter, exercise.level != levelFilter { return false }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return exercise.name.lowercased().contains(query)
            || exercise.summary.lowercased().contains(query)
            || exercise.muscles.lowercased().contains(query)
            || exercise.category.title.lowercased().contains(query)
    }

    var body: some View {
        NavigationStack {
            List {
                if !isFiltering {
                    Section {
                        NavigationLink {
                            JourneyView()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "map.fill")
                                    .font(.title3)
                                    .foregroundStyle(.black)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.warm, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Your journey").font(.headline)
                                    Text("Level \(playerLevel) · \(Progression.unlocked(playerLevel: playerLevel).count) of \(ExerciseLibrary.all.count) exercises unlocked")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Button {
                            routineRunning = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(.black)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Daily Face Workout").font(.headline)
                                    Text("\(dailyRoutine.count) exercises · about \(dailyRoutineDuration.clockString) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.fill").foregroundStyle(Theme.accent)
                            }
                        }
                        .foregroundStyle(.primary)
                    }

                    Section("Programs") {
                        ForEach(ProgramLibrary.all) { program in
                            let required = Progression.unlockLevel(forProgram: program.id)
                            if playerLevel >= required {
                                NavigationLink {
                                    ProgramDetailView(program: program)
                                } label: {
                                    ProgramRow(program: program)
                                }
                            } else {
                                HStack(spacing: 14) {
                                    Image(systemName: "lock.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(program.name).font(.headline).foregroundStyle(.secondary)
                                        Text("Unlocks at level \(required)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.warm)
                                    }
                                }
                            }
                        }
                    }

                    let saved = ExerciseLibrary.all.filter { favourites.contains($0.id) }
                    if !saved.isEmpty {
                        Section("Favourites") { rows(saved) }
                    }
                }

                ForEach(ExerciseCategory.allCases) { category in
                    let items = ExerciseLibrary.exercises(in: category).filter(matches)
                    if !items.isEmpty {
                        Section {
                            rows(items)
                        } header: {
                            Label(category.title, systemImage: category.symbol)
                        }
                    }
                }

                if isFiltering, ExerciseLibrary.all.filter(matches).isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Exercises")
            .searchable(text: $searchText, prompt: "Search face exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Level", selection: $levelFilter) {
                            Text("All levels").tag(ExerciseLevel?.none)
                            ForEach(ExerciseLevel.allCases, id: \.self) { level in
                                Text(level.title).tag(ExerciseLevel?.some(level))
                            }
                        }
                    } label: {
                        Image(systemName: levelFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .fullScreenCover(isPresented: $routineRunning) {
                ExerciseSessionView(exercises: dailyRoutine)
            }
            .alert("Locked", isPresented: Binding(get: { lockedExercise != nil },
                                                  set: { if !$0 { lockedExercise = nil } })) {
                Button("OK", role: .cancel) { lockedExercise = nil }
            } message: {
                if let lockedExercise {
                    Text("\(lockedExercise.name) unlocks at level \(Progression.unlockLevel(for: lockedExercise.id)). Keep training to earn XP — you're on level \(playerLevel).")
                }
            }
        }
    }

    /// The daily workout only uses exercises you've unlocked.
    private var dailyRoutine: [Exercise] {
        let unlocked = ExerciseLibrary.dailyRoutine.filter { Progression.isUnlocked($0, playerLevel: playerLevel) }
        return unlocked.isEmpty ? Array(Progression.unlocked(playerLevel: playerLevel).prefix(3)) : unlocked
    }

    private var dailyRoutineDuration: TimeInterval {
        dailyRoutine.reduce(0) { $0 + $1.estimatedDuration }
    }

    private func rows(_ items: [Exercise]) -> some View {
        ForEach(items) { exercise in
            let unlocked = Progression.isUnlocked(exercise, playerLevel: playerLevel)
            let mastery = Progression.mastery(reps: Progression.reps(for: exercise.id, in: sessions))
            if unlocked {
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    ExerciseRow(exercise: exercise, isFavourite: favourites.contains(exercise.id), mastery: mastery)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        toggleFavourite(exercise.id)
                    } label: {
                        Label(favourites.contains(exercise.id) ? "Unsave" : "Save",
                              systemImage: favourites.contains(exercise.id) ? "star.slash" : "star")
                    }
                    .tint(Theme.warm)
                }
            } else {
                Button {
                    lockedExercise = exercise
                } label: {
                    ExerciseRow(exercise: exercise, isLocked: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleFavourite(_ id: String) {
        var saved = favourites
        if saved.contains(id) {
            saved.remove(id)
        } else {
            saved.insert(id)
        }
        favouritesRaw = saved.sorted().joined(separator: ",")
    }
}
