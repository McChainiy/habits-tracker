import SwiftData
import SwiftUI

private struct DraftHabit: Identifiable {
    let id = UUID()
    var title = ""
    var note = ""
    var penaltyText = ""
    var colorHex: String
    var scheduleMode: HabitScheduleMode = .days
    var scheduledWeekdays: Set<Int>
    var weeklyTarget = 3
    var reminderTimes: [String] = []
}

struct SetupChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \AppUser.createdAt)
    private var users: [AppUser]

    var onCreate: (() -> Void)?

    @State private var title = "Тело в ритме"
    @State private var selectedStartDate = Date()
    @State private var colorHex = HabitColor.sage.rawValue
    @State private var durationWeeks = 4
    @State private var targetWeeks = 3
    @State private var isTimeless = false
    @State private var rewardText = "После челленджа я покупаю себе новую книгу и выделяю вечер без дел."
    @State private var draftHabits: [DraftHabit] = [
        DraftHabit(
            title: "Гулять 40 минут",
            note: "Свежий воздух без телефона в руках.",
            penaltyText: "Перевести 500 ₽ в фонд, который я не поддерживаю.",
            colorHex: HabitColor.sage.rawValue,
            scheduledWeekdays: [1, 2, 5]
        ),
        DraftHabit(
            title: "Спорт 30 минут",
            note: "Тренировка дома или зал.",
            penaltyText: "Без сериалов до следующей тренировки.",
            colorHex: HabitColor.blue.rawValue,
            scheduledWeekdays: [3, 4, 6]
        )
    ]

    private let weekdays = [
        (1, "ПН"),
        (2, "ВТ"),
        (3, "СР"),
        (4, "ЧТ"),
        (5, "ПТ"),
        (6, "СБ"),
        (7, "ВС")
    ]

    private var clampedTargetWeeks: Int {
        min(max(targetWeeks, 1), max(durationWeeks, 1))
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftHabits.isEmpty &&
        draftHabits.count <= 5 &&
        draftHabits.allSatisfy { draft in
            !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (draft.scheduleMode == .count || !draft.scheduledWeekdays.isEmpty)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                challengePanel
                habitsPanel
                conditionPanel
                rewardPanel

                Button("Начать челлендж") {
                    createChallenge()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.45)
            }
            .padding(20)
        }
        .background(AppPalette.paper.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: durationWeeks) { _, newValue in
            durationWeeks = min(max(newValue, 1), 100)
            targetWeeks = min(max(targetWeeks, 1), durationWeeks)
        }
        .onChange(of: targetWeeks) { _, newValue in
            targetWeeks = min(max(newValue, 1), max(durationWeeks, 1))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Новый челлендж")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.muted)

            TextField("Название челленджа", text: $title)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .textFieldStyle(.plain)
        }
    }

    private var challengePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Цвет челленджа")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.muted)

            colorPicker(selection: $colorHex)

            DatePicker("Старт", selection: $selectedStartDate, displayedComponents: [.date])
                .font(.system(size: 15, weight: .semibold))
                .tint(AppPalette.accent)
        }
        .panelStyle()
    }

    private var habitsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Привычки в челлендже")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.muted)

            ForEach($draftHabits) { $habit in
                habitRow($habit)
            }

            if draftHabits.count < 5 {
                Button {
                    let color = HabitColor.allCases[draftHabits.count % HabitColor.allCases.count]
                    draftHabits.append(
                        DraftHabit(
                            colorHex: color.rawValue,
                            scheduledWeekdays: [1, 3, 5]
                        )
                    )
                } label: {
                    Label("Добавить привычку", systemImage: "plus")
                }
                .buttonStyle(DashedButtonStyle())
            }
        }
        .panelStyle()
    }

    private func habitRow(_ habit: Binding<DraftHabit>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                colorDot(colorHex: habit.wrappedValue.colorHex)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Название привычки", text: habit.title)
                        .font(.system(size: 16, weight: .semibold))
                        .textFieldStyle(.plain)

                    TextField("Описание", text: habit.note, axis: .vertical)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.muted)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                }

                scheduleModePicker(selection: habit.scheduleMode)
            }

            colorPicker(selection: habit.colorHex)

            if habit.wrappedValue.scheduleMode == .days {
                weekdayPicker(selection: habit.scheduledWeekdays)
            } else {
                weeklyTargetStepper(value: habit.weeklyTarget)
            }

            TextField("Наказание за пропуск", text: habit.penaltyText, axis: .vertical)
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.ink)
                .lineLimit(1...3)
                .padding(10)
                .background(AppPalette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppPalette.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppPalette.line.opacity(0.8))
                .frame(height: 1)
        }
    }

    private var conditionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Срок и условие выполнения")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.muted)

            Stepper(value: $durationWeeks, in: 1...100) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Срок челленджа")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(durationWeeks) \(weekWord(durationWeeks))")
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.muted)
                }
            }
            .disabled(isTimeless)
            .opacity(isTimeless ? 0.45 : 1)

            Toggle(isOn: $isTimeless) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Без срока окончания")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Привычки продолжаются, пока я сам не завершу челлендж.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.muted)
                }
            }
            .tint(AppPalette.accent)

            Stepper(value: $targetWeeks, in: 1...max(durationWeeks, 1)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Успешных недель")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(clampedTargetWeeks) \(successWeekWord(clampedTargetWeeks))")
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.muted)
                }
            }
            .disabled(isTimeless)
            .opacity(isTimeless ? 0.45 : 1)

            if !isTimeless {
                Slider(
                    value: Binding(
                        get: { Double(clampedTargetWeeks) },
                        set: { targetWeeks = Int($0.rounded()) }
                    ),
                    in: 1...Double(max(durationWeeks, 1)),
                    step: 1
                )
                .tint(AppPalette.accent)
            }

            Text(conditionText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.accent)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .panelStyle()
    }

    private var rewardPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Моя награда")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.451, green: 0.373, blue: 0.129))

            TextField("Что я себе разрешу после успеха", text: $rewardText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.ink)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
        }
        .padding(16)
        .background(AppPalette.sunSoft)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 0.875, green: 0.800, blue: 0.537), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var conditionText: String {
        if isTimeless {
            return "Челлендж продолжается без срока окончания. Успешные недели копятся как серия, а завершить его можно вручную."
        }
        return "Челлендж засчитывается, если набрано \(clampedTargetWeeks) \(successWeekWord(clampedTargetWeeks)) из \(durationWeeks) \(weekWord(durationWeeks))."
    }

    private func scheduleModePicker(selection: Binding<HabitScheduleMode>) -> some View {
        HStack(spacing: 3) {
            ForEach(HabitScheduleMode.allCases) { mode in
                Button {
                    selection.wrappedValue = mode
                } label: {
                    Text(mode == .days ? "дни" : "раз")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selection.wrappedValue == mode ? AppPalette.ink : AppPalette.muted)
                        .frame(width: 38, height: 28)
                        .background(selection.wrappedValue == mode ? AppPalette.surface : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppPalette.soft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func weekdayPicker(selection: Binding<Set<Int>>) -> some View {
        HStack(spacing: 6) {
            ForEach(weekdays, id: \.0) { value, title in
                let isActive = selection.wrappedValue.contains(value)
                Button {
                    if isActive {
                        selection.wrappedValue.remove(value)
                    } else {
                        selection.wrappedValue.insert(value)
                    }
                } label: {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isActive ? AppPalette.accent : AppPalette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(isActive ? AppPalette.accentSoft : AppPalette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isActive ? AppPalette.accent : AppPalette.line, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func weeklyTargetStepper(value: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value.wrappedValue) \(timesWord(value.wrappedValue)) в неделю")
                    .font(.system(size: 13, weight: .semibold))
                Text("Любые дни, когда получилось.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppPalette.muted)
            }

            Spacer()

            Stepper("", value: value, in: 1...7)
                .labelsHidden()
        }
        .padding(10)
        .background(AppPalette.paper)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func colorPicker(selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(HabitColor.allCases) { color in
                Button {
                    selection.wrappedValue = color.rawValue
                } label: {
                    Circle()
                        .fill(Color(hex: color.rawValue))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(AppPalette.surface, lineWidth: 2)
                        )
                        .shadow(color: selection.wrappedValue == color.rawValue ? AppPalette.ink.opacity(0.35) : .clear, radius: 0, x: 0, y: 0)
                        .overlay(
                            Circle()
                                .stroke(AppPalette.ink, lineWidth: selection.wrappedValue == color.rawValue ? 2 : 0)
                                .padding(-2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Выбрать цвет")
            }
        }
    }

    private func colorDot(colorHex: String) -> some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: 12, height: 12)
    }

    private func createChallenge() {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: selectedStartDate)
        let components = calendar.dateComponents([.year, .month], from: startDate)
        guard let year = components.year, let month = components.month else { return }

        let finalDuration = min(max(durationWeeks, 1), 100)
        let finalTarget = min(max(targetWeeks, 1), finalDuration)
        let endDate = calendar.date(byAdding: .day, value: finalDuration * 7 - 1, to: startDate) ?? startDate

        let challenge = Challenge(
            customTitle: title.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex,
            month: month,
            year: year,
            startDate: startDate,
            endDate: endDate,
            durationWeeks: finalDuration,
            targetWeeks: finalTarget,
            isTimeless: isTimeless,
            rewardText: rewardText.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .active,
            user: users.first
        )

        for (index, draft) in draftHabits.enumerated() {
            let habit = Habit(
                userId: users.first?.id,
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
                penaltyText: draft.penaltyText.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: draft.colorHex,
                scheduleMode: draft.scheduleMode,
                scheduledWeekdays: draft.scheduledWeekdays,
                weeklyTarget: draft.weeklyTarget,
                reminderTimes: draft.reminderTimes,
                sortOrder: index,
                challenge: challenge
            )
            challenge.habits.append(habit)
        }

        modelContext.insert(challenge)
        try? modelContext.save()
        onCreate?()
        dismiss()
    }

    private func weekWord(_ value: Int) -> String {
        let last = value % 10
        let lastTwo = value % 100
        if last == 1 && lastTwo != 11 { return "неделя" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "недели" }
        return "недель"
    }

    private func successWeekWord(_ value: Int) -> String {
        let last = value % 10
        let lastTwo = value % 100
        if last == 1 && lastTwo != 11 { return "успешная неделя" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "успешные недели" }
        return "успешных недель"
    }

    private func timesWord(_ value: Int) -> String {
        let last = value % 10
        let lastTwo = value % 100
        if last == 1 && lastTwo != 11 { return "раз" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "раза" }
        return "раз"
    }
}

private struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppPalette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppPalette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension View {
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }
}

private struct DashedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(AppPalette.paper.opacity(configuration.isPressed ? 0.55 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppPalette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
