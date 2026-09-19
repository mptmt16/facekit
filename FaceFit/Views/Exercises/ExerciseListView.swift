import SwiftUI

struct ExerciseListView: View {
    @AppStorage(SettingsKey.favouriteExercises) private var favouritesRaw = ""
    @State private var searchText = ""
    @State private var levelFilter: ExerciseLevel?
    @State private var routineRunning = false

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
                                    Text("\(ExerciseLibrary.dailyRoutine.count) exercises · about \(ExerciseLibrary.dailyRoutineDuration.clockString) min")
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
                            NavigationLink {
                                ProgramDetailView(program: program)
                            } label: {
                                ProgramRow(program: program)
                            }
                        }
                    }

                    let saved = ExerciseLibrary.all.filter { favourites.contains($0.id) }
                    if !saved.isEmpty {
                        Section("Favourites") {
                            rows(saved)
                        }
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
                ExerciseSessionView(exercises: ExerciseLibrary.dailyRoutine)
            }
        }
    }

    private func rows(_ items: [Exercise]) -> some View {
        ForEach(items) { exercise in
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                ExerciseRow(exercise: exercise, isFavourite: favourites.contains(exercise.id))
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
