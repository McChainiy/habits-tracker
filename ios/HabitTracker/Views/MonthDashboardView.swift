import SwiftData
import SwiftUI

struct WeeklyDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Habit.createdAt)
    private var habits: [Habit]

    let challenges: [Challenge]

    @State private var sheet: DashboardSheet?
    @State private var isCreateDialogPresented = false
    @State private var selectedFilter: ChallengeFilter = .all

    private let calendar = Calendar.current
    private let weekdays = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var weekDates: [Date] {
        let weekStart = calendar.startOfWeek(for: Date())
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    private var visibleChallenges: [Challenge] {
        challenges
            .filter { $0.deletedAt == nil }
            .sorted { $0.startDate < $1.startDate }
    }

    private var orphanHabits: [Habit] {
        habits
            .filter { habit in
                habit.challenge == nil &&
                !habit.isArchived &&
                habit.deletedAt == nil
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var rows: [WeeklyHabitRow] {
        switch selectedFilter {
        case .all:
            return challengeRows + orphanRows
        case .challenge(let id):
            return visibleChallenges
                .filter { $0.id == id }
                .flatMap(rows(for:))
        case .noChallenge:
            return orphanRows
        }
    }

    private var challengeRows: [WeeklyHabitRow] {
        visibleChallenges.flatMap(rows(for:))
    }

    private var orphanRows: [WeeklyHabitRow] {
        orphanHabits.map {
            WeeklyHabitRow(challenge: nil, habit: $0)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    weekGrid
                }
                .padding(20)
                .padding(.bottom, 86)
            }
            .background(AppPalette.paper.ignoresSafeArea())

            Button {
                isCreateDialogPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppPalette.surface)
                    .frame(width: 58, height: 58)
                    .background(AppPalette.ink)
                    .clipShape(Circle())
                    .shadow(color: AppPalette.ink.opacity(0.24), radius: 18, x: 0, y: 12)
            }
            .buttonStyle(.plain)
            .padding(24)
            .accessibilityLabel("Создать")
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Что добавить", isPresented: $isCreateDialogPresented, titleVisibility: .visible) {
            Button("Добавить привычку") {
                sheet = .newHabit
            }
            Button("Добавить челлендж") {
                sheet = .newChallenge
            }
        }
        .sheet(item: $sheet) { item in
            NavigationStack {
                switch item {
                case .newHabit:
                    HabitFormView(challenges: visibleChallenges)
                case .newChallenge:
                    SetupChallengeView()
                }
            }
            .presentationDetents([.large])
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Общий план")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.muted)
                Text("Эта неделя")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }

            Spacer()

            Menu {
                Button("Все челленджи") {
                    selectedFilter = .all
                }

                ForEach(visibleChallenges, id: \.id) { challenge in
                    Button(challenge.title) {
                        selectedFilter = .challenge(challenge.id)
                    }
                }

                Button("Без челленджа") {
                    selectedFilter = .noChallenge
                }
            } label: {
                HStack(spacing: 6) {
                    Text(filterTitle)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.muted)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(AppPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppPalette.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var weekGrid: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            GridRow {
                Text("Привычки")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.muted)
                    .frame(width: 98, alignment: .leading)
                    .frame(minHeight: 42)

                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, weekday in
                    dayHeader(weekday, date: weekDates[index])
                }
            }

            ForEach(rows) { row in
                GridRow {
                    habitHeader(row)

                    ForEach(weekDates, id: \.self) { date in
                        Button {
                            cycleStatus(for: row.habit, on: date)
                        } label: {
                            HabitWeekCell(
                                state: state(for: row.habit, on: date),
                                color: Color(hex: row.habit.colorHex),
                                isToday: calendar.isDateInToday(date)
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Выполнено") {
                                setStatus(.done, for: row.habit, on: date)
                            }
                            Button("Пропуск") {
                                setStatus(.skipped, for: row.habit, on: date)
                            }
                            Button("Провал") {
                                setStatus(.failed, for: row.habit, on: date)
                            }
                        }
                        .accessibilityLabel("\(row.habit.title), \(date.formatted(.dateTime.weekday(.wide)))")
                    }
                }
            }
        }
        .padding(12)
        .background(AppPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func dayHeader(_ title: String, date: Date) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(calendar.isDateInToday(date) ? AppPalette.ink : AppPalette.muted)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(AppPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(calendar.isDateInToday(date) ? AppPalette.ink.opacity(0.28) : AppPalette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func habitHeader(_ row: WeeklyHabitRow) -> some View {
        Text(row.habit.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppPalette.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .frame(width: 98, alignment: .leading)
            .frame(minHeight: 42)
            .background(Color(hex: row.habit.colorHex).opacity(0.06))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: row.habit.colorHex))
                    .frame(width: 5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppPalette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var filterTitle: String {
        switch selectedFilter {
        case .all:
            return "\(visibleChallenges.count) \(challengeWord(visibleChallenges.count))"
        case .challenge(let id):
            return visibleChallenges.first { $0.id == id }?.title ?? "Челлендж"
        case .noChallenge:
            return "Без челленджа"
        }
    }

    private func rows(for challenge: Challenge) -> [WeeklyHabitRow] {
        challenge.habits
            .filter { !$0.isArchived && $0.deletedAt == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { WeeklyHabitRow(challenge: challenge, habit: $0) }
    }

    private func state(for habit: Habit, on date: Date) -> HabitWeekCell.State {
        switch entry(for: habit, on: date)?.status {
        case .done:
            return .done
        case .failed:
            return .failed
        case .skipped:
            return .rest
        case .none:
            return isPlanned(habit, on: date) ? .planned : .rest
        }
    }

    private func isPlanned(_ habit: Habit, on date: Date) -> Bool {
        switch habit.scheduleMode {
        case .days:
            return habit.scheduledWeekdays.contains(calendar.mondayWeekdayIndex(for: date))
        case .count:
            let completedThisWeek = weekDates.filter {
                entry(for: habit, on: $0)?.status == .done
            }.count
            return completedThisWeek < max(habit.weeklyTarget, 1)
        }
    }

    private func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        let normalizedDate = calendar.startOfDay(for: date)
        return habit.entries.first {
            calendar.isDate($0.entryDate, inSameDayAs: normalizedDate) && $0.deletedAt == nil
        }
    }

    private func cycleStatus(for habit: Habit, on date: Date) {
        let current = entry(for: habit, on: date)?.status
        if current == .done {
            setStatus(.skipped, for: habit, on: date)
        } else {
            setStatus(.done, for: habit, on: date)
        }
    }

    private func setStatus(_ status: HabitEntryStatus, for habit: Habit, on date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)

        if let existing = entry(for: habit, on: normalizedDate) {
            existing.status = status
        } else {
            let entry = HabitEntry(
                userId: habit.userId,
                entryDate: normalizedDate,
                status: status,
                habit: habit
            )
            habit.entries.append(entry)
            modelContext.insert(entry)
        }

        try? modelContext.save()
    }

    private func challengeWord(_ value: Int) -> String {
        let last = value % 10
        let lastTwo = value % 100
        if last == 1 && lastTwo != 11 { return "челлендж" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "челленджа" }
        return "челленджей"
    }
}

private enum ChallengeFilter: Equatable {
    case all
    case challenge(UUID)
    case noChallenge
}

private enum DashboardSheet: Identifiable {
    case newHabit
    case newChallenge

    var id: String {
        switch self {
        case .newHabit: return "newHabit"
        case .newChallenge: return "newChallenge"
        }
    }
}

private struct WeeklyHabitRow: Identifiable {
    let challenge: Challenge?
    let habit: Habit

    var id: UUID { habit.id }
}

private struct HabitWeekCell: View {
    enum State {
        case done
        case failed
        case planned
        case rest
    }

    let state: State
    let color: Color
    let isToday: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border, lineWidth: isToday ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
    }

    private var label: String {
        switch state {
        case .done: return "✓"
        case .failed: return "×"
        case .planned, .rest: return ""
        }
    }

    private var foreground: Color {
        switch state {
        case .done:
            return AppPalette.surface
        case .failed:
            return AppPalette.warning
        case .planned, .rest:
            return AppPalette.muted
        }
    }

    private var background: Color {
        switch state {
        case .done:
            return color
        case .failed:
            return AppPalette.warningSoft
        case .planned:
            return color.opacity(0.18)
        case .rest:
            return AppPalette.surface.opacity(0.42)
        }
    }

    private var border: Color {
        if isToday {
            return AppPalette.ink.opacity(0.30)
        }

        switch state {
        case .done:
            return color
        case .failed:
            return AppPalette.warning
        case .planned:
            return color.opacity(0.42)
        case .rest:
            return AppPalette.line.opacity(0.72)
        }
    }
}

private struct HabitFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let challenges: [Challenge]

    @State private var selectedChallengeID: UUID?
    @State private var title = "Читать 20 минут"
    @State private var note = "Перед сном, без телефона рядом. Если день сложный, достаточно 10 минут."
    @State private var penaltyText = ""
    @State private var colorHex = HabitColor.sage.rawValue
    @State private var scheduleMode: HabitScheduleMode = .days
    @State private var scheduledWeekdays: Set<Int> = [2, 4, 7]
    @State private var weeklyTarget = 3
    @State private var reminderTimes: Set<String> = ["20:30"]

    private let weekdays = [
        (1, "ПН"),
        (2, "ВТ"),
        (3, "СР"),
        (4, "ЧТ"),
        (5, "ПТ"),
        (6, "СБ"),
        (7, "ВС")
    ]
    private let suggestedTimes = ["08:30", "20:30", "22:00"]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (scheduleMode == .count || !scheduledWeekdays.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Новая привычка")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.muted)

                formPanel
                schedulePanel
                reminderPanel

                Button("Сохранить привычку") {
                    saveHabit()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
            }
            .padding(20)
        }
        .background(AppPalette.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedChallengeID = selectedChallengeID ?? challenges.first?.id
        }
    }

    private var formPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !challenges.isEmpty {
                Picker("Челлендж", selection: Binding(
                    get: { selectedChallengeID },
                    set: { selectedChallengeID = $0 }
                )) {
                    Text("Без челленджа").tag(Optional<UUID>.none)
                    ForEach(challenges, id: \.id) { challenge in
                        Text(challenge.title).tag(Optional(challenge.id))
                    }
                }
                .pickerStyle(.menu)
            }

            labeledField("Название") {
                TextField("Название привычки", text: $title)
                    .font(.system(size: 15))
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(AppPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppPalette.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            labeledField("Описание") {
                TextField("Описание привычки", text: $note, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(3...5)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(AppPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppPalette.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            labeledField("Цвет") {
                colorPicker
            }

            labeledField("Наказание за пропуск") {
                TextField("Личный контракт", text: $penaltyText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(AppPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppPalette.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .weeklyPanelStyle()
    }

    private var schedulePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Расписание")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.muted)

            HStack(spacing: 6) {
                segment("конкретные дни", mode: .days)
                segment("раз в неделю", mode: .count)
            }
            .padding(4)
            .background(AppPalette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if scheduleMode == .days {
                weekdayPicker
            } else {
                HStack(spacing: 12) {
                    Text("Выполнений в неделю")
                        .font(.system(size: 14))
                    Spacer()
                    Stepper("\(weeklyTarget)", value: $weeklyTarget, in: 1...7)
                        .labelsHidden()
                    Text("\(weeklyTarget)")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 24)
                }
                .padding(10)
                .background(AppPalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .weeklyPanelStyle()
    }

    private var reminderPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Напоминания")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.muted)

            HStack(spacing: 8) {
                ForEach(suggestedTimes, id: \.self) { time in
                    let isActive = reminderTimes.contains(time)
                    Button {
                        if isActive {
                            reminderTimes.remove(time)
                        } else {
                            reminderTimes.insert(time)
                        }
                    } label: {
                        Text(time)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive ? AppPalette.accent : AppPalette.muted)
                            .padding(.horizontal, 12)
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
        .weeklyPanelStyle()
    }

    private var colorPicker: some View {
        HStack(spacing: 8) {
            ForEach(HabitColor.allCases) { color in
                Button {
                    colorHex = color.rawValue
                } label: {
                    Circle()
                        .fill(Color(hex: color.rawValue))
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(AppPalette.surface, lineWidth: 2))
                        .overlay(
                            Circle()
                                .stroke(AppPalette.ink, lineWidth: colorHex == color.rawValue ? 2 : 0)
                                .padding(-2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(weekdays, id: \.0) { value, title in
                let isActive = scheduledWeekdays.contains(value)
                Button {
                    if isActive {
                        scheduledWeekdays.remove(value)
                    } else {
                        scheduledWeekdays.insert(value)
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

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.muted)
            content()
        }
    }

    private func segment(_ title: String, mode: HabitScheduleMode) -> some View {
        Button {
            scheduleMode = mode
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(scheduleMode == mode ? AppPalette.ink : AppPalette.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(scheduleMode == mode ? AppPalette.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func saveHabit() {
        let challenge = challenges.first { $0.id == selectedChallengeID }
        let nextSortOrder = if let challenge {
            (challenge.habits.map(\.sortOrder).max() ?? -1) + 1
        } else {
            0
        }
        let habit = Habit(
            userId: challenge?.user?.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            penaltyText: penaltyText.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex,
            scheduleMode: scheduleMode,
            scheduledWeekdays: scheduledWeekdays,
            weeklyTarget: weeklyTarget,
            reminderTimes: reminderTimes.sorted(),
            sortOrder: nextSortOrder,
            challenge: challenge
        )
        if let challenge {
            challenge.habits.append(habit)
            challenge.touch()
        }
        modelContext.insert(habit)
        try? modelContext.save()
        dismiss()
    }
}

private struct WeeklyPanelStyle: ViewModifier {
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
    func weeklyPanelStyle() -> some View {
        modifier(WeeklyPanelStyle())
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let normalizedDate = startOfDay(for: date)
        let weekday = component(.weekday, from: normalizedDate)
        let mondayOffset = (weekday + 5) % 7
        return self.date(byAdding: .day, value: -mondayOffset, to: normalizedDate) ?? normalizedDate
    }

    func mondayWeekdayIndex(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return ((weekday + 5) % 7) + 1
    }
}
