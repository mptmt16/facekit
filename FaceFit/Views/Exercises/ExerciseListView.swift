import SwiftUI

struct ExerciseListView: View {
    @State private var routineRunning = false

    var body: some View {
        NavigationStack {
            List {
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

                ForEach(ExerciseCategory.allCases) { category in
                    Section {
                        ForEach(ExerciseLibrary.exercises(in: category)) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise)
                            }
                        }
                    } header: {
                        Label(category.title, systemImage: category.symbol)
                    }
                }
            }
            .navigationTitle("Exercises")
            .fullScreenCover(isPresented: $routineRunning) {
                ExerciseSessionView(exercises: ExerciseLibrary.dailyRoutine)
            }
        }
    }
}
