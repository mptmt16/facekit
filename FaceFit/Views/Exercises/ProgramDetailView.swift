import SwiftUI

struct ProgramRow: View {
    let program: Program

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: program.symbol)
                .font(.title3)
                .foregroundStyle(program.color)
                .frame(width: 44, height: 44)
                .background(program.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(program.name).font(.headline)
                Text("\(program.exercises.count) exercises · about \(program.duration.clockString) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProgramDetailView: View {
    let program: Program

    @State private var running = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: program.symbol)
                        .font(.system(size: 40))
                        .foregroundStyle(program.color)
                    Text(program.name).font(.title.bold())
                    Text(program.summary).foregroundStyle(.secondary)
                    Label("\(program.exercises.count) exercises · about \(program.duration.clockString) min",
                          systemImage: "clock")
                        .font(.subheadline)
                }
                .padding(.vertical, 6)

                Button("Start program") { running = true }
                    .buttonStyle(PrimaryButtonStyle(color: program.color))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Exercises") {
                ForEach(Array(program.exercises.enumerated()), id: \.offset) { index, exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            ExerciseRow(exercise: exercise)
                        }
                    }
                }
            }
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $running) {
            ExerciseSessionView(exercises: program.exercises)
        }
    }
}
