import SwiftData
import SwiftUI

private struct DraftHabit: Identifiable {
    let id = UUID()
    var title = ""
    var penaltyText = ""
    var colorHex: String
}

struct SetupChallengeView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate = Date()
    @State private var draftHabits: [DraftHabit] = [
        DraftHabit(colorHex: HabitColor.sage.rawValue)
    ]

    private var canCreate: Bool {
        !draftHabits.isEmpty &&
        draftHabits.count <= 5 &&
        draftHabits.allSatisfy {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.penaltyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                habitsEditor
                Button("Создать месяц") {
                    createChallenge()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.45)
            }
            .padding(24)
        }
        .background(AppPalette.paper.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Новый месяц")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            Text("Выберите до пяти привычек и заранее задайте честное наказание за пропуск.")
                .font(.system(size: 17))
                .foregroundStyle(AppPalette.muted)
                .lineSpacing(3)

            DatePicker("Месяц", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .padding(.top, 4)
        }
    }

    private var habitsEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach($draftHabits) { $habit in
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Привычка", text: $habit.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium))

                    TextField("Наказание за пропуск", text: $habit.penaltyText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.ink)
                        .lineLimit(2...4)

                    HStack(spacing: 8) {
                        ForEach(HabitColor.allCases) { color in
                            Button {
                                habit.colorHex = color.rawValue
                            } label: {
                                Circle()
                                    .fill(Color(hex: color.rawValue))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(AppPalette.ink, lineWidth: habit.colorHex == color.rawValue ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Выбрать цвет")
                        }
                    }
                }
                .padding(16)
                .background(AppPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppPalette.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if draftHabits.count < 5 {
                Button("+ Добавить привычку") {
                    let color = HabitColor.allCases[draftHabits.count % HabitColor.allCases.count]
                    draftHabits.append(DraftHabit(colorHex: color.rawValue))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func createChallenge() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard
            let year = components.year,
            let month = components.month,
            let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let dayRange = calendar.range(of: .day, in: .month, for: startDate),
            let endDate = calendar.date(from: DateComponents(year: year, month: month, day: dayRange.count))
        else {
            return
        }

        let challenge = Challenge(
            month: month,
            year: year,
            startDate: startDate,
            endDate: endDate,
            status: .active
        )

        for (index, draft) in draftHabits.enumerated() {
            let habit = Habit(
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                penaltyText: draft.penaltyText.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: draft.colorHex,
                sortOrder: index,
                challenge: challenge
            )
            challenge.habits.append(habit)
        }

        modelContext.insert(challenge)
        try? modelContext.save()
    }
}
