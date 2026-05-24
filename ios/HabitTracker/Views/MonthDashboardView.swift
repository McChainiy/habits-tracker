import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WeeklyDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Habit.createdAt)
    private var habits: [Habit]

    let challenges: [Challenge]

    @State private var sheet: DashboardSheet?
    @State private var isCreateMenuPresented = false
    @State private var highlightedCreateAction: CreateAction?
    @State private var selectedFilter: ChallengeFilter = .all
    @State private var highlightedChallengeID: UUID?
    @State private var challengePressFeedbackTask: Task<Void, Never>?
    @State private var isMonthCalendarPresented = false
    @State private var selectedWeekStart = Calendar.current.startOfWeek(for: Date())
    @State private var visibleMonthDate = Calendar.current.startOfMonth(for: Date())

    private let calendar = Calendar.current
    private let weekdays = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var weekDates: [Date] {
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: selectedWeekStart)
        }
    }

    private var selectedWeekEnd: Date {
        calendar.date(byAdding: .day, value: 6, to: selectedWeekStart)
            .map(calendar.startOfDay(for:)) ?? selectedWeekStart
    }

    private var activeChallenges: [Challenge] {
        challenges
            .filter { $0.deletedAt == nil }
            .sorted { $0.startDate < $1.startDate }
    }

    private var visibleChallenges: [Challenge] {
        activeChallenges
            .filter {
                wasCreatedBySelectedWeek($0.createdAt) &&
                isActiveDuringSelectedWeek($0)
            }
    }

    private var orphanHabits: [Habit] {
        habits
            .filter { habit in
                habit.challenge == nil &&
                !habit.isArchived &&
                habit.deletedAt == nil &&
                wasCreatedBySelectedWeek(habit.createdAt)
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
                    if isMonthCalendarPresented {
                        monthCalendar
                    }
                    weekGrid
                }
                .padding(20)
                .padding(.bottom, 86)
            }
            .background(AppPalette.paper.ignoresSafeArea())

            if isCreateMenuPresented {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeCreateMenu()
                    }
            }

            createLauncher
                .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopChallengePressFeedback()
        }
        .sheet(item: $sheet, onDismiss: {
            highlightedChallengeID = nil
            closeCreateMenu()
        }) { item in
            NavigationStack {
                switch item {
                case .newHabit:
                    HabitFormView(challenges: activeChallenges)
                case .newChallenge:
                    SetupChallengeView()
                case .editHabit(let habit):
                    HabitFormView(challenges: activeChallenges, habit: habit)
                case .editChallenge(let challenge):
                    SetupChallengeView(challenge: challenge)
                }
            }
            .presentationDetents([.large])
        }
    }

    private var createLauncher: some View {
        ZStack(alignment: .bottomTrailing) {
            if isCreateMenuPresented {
                createOption(.challenge)
                    .offset(x: -4, y: -142)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.82, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .opacity
                    ))

                createOption(.habit)
                    .offset(x: -86, y: -78)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.82, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppPalette.surface)
                .rotationEffect(.degrees(isCreateMenuPresented ? 45 : 0))
                .frame(width: 58, height: 58)
                .background(AppPalette.ink)
                .clipShape(Circle())
                .shadow(color: AppPalette.ink.opacity(0.24), radius: 18, x: 0, y: 12)
                .contentShape(Circle())
                .onTapGesture {
                    toggleCreateMenu()
                }
                .gesture(createDragGesture)
                .accessibilityLabel("Создать")
                .accessibilityAddTraits(.isButton)
        }
        .frame(width: 236, height: 220, alignment: .bottomTrailing)
    }

    private func toggleCreateMenu() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            isCreateMenuPresented.toggle()
            highlightedCreateAction = nil
        }
    }

    private func createOption(_ action: CreateAction) -> some View {
        Button {
            presentCreateAction(action)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(action.title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(highlightedCreateAction == action ? AppPalette.surface : AppPalette.ink)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(highlightedCreateAction == action ? AppPalette.ink : AppPalette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(highlightedCreateAction == action ? AppPalette.ink : AppPalette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: AppPalette.ink.opacity(0.14), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var createDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard value.translation.height < -8 else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isCreateMenuPresented = true
                    highlightedCreateAction = createAction(for: value.translation)
                }
            }
            .onEnded { value in
                if let action = createAction(for: value.translation) {
                    presentCreateAction(action)
                } else if isCreateMenuPresented {
                    highlightedCreateAction = nil
                }
            }
    }

    private func createAction(for translation: CGSize) -> CreateAction? {
        guard translation.height < -28 else { return nil }
        return translation.height < -96 ? .challenge : .habit
    }

    private func presentCreateAction(_ action: CreateAction) {
        closeCreateMenu()
        switch action {
        case .habit:
            sheet = .newHabit
        case .challenge:
            sheet = .newChallenge
        }
    }

    private func closeCreateMenu() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
            isCreateMenuPresented = false
            highlightedCreateAction = nil
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleMonthCalendar()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isMonthCalendarPresented ? AppPalette.surface : AppPalette.ink)
                        .frame(width: 38, height: 38)
                        .background(isMonthCalendarPresented ? AppPalette.ink : AppPalette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isMonthCalendarPresented ? AppPalette.ink : AppPalette.line, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isMonthCalendarPresented ? "Закрыть календарь" : "Открыть календарь")

                VStack(alignment: .leading, spacing: 7) {
                    Text(dashboardTitle)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if shouldShowCurrentWeekButton {
                        Button {
                            selectCurrentWeek()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Эта неделя")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(AppPalette.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(AppPalette.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Menu {
                Button {
                    selectedFilter = .all
                } label: {
                    Label("Все челленджи", systemImage: "square.grid.2x2")
                }

                Divider()

                ForEach(visibleChallenges, id: \.id) { challenge in
                    Button(challenge.title) {
                        selectedFilter = .challenge(challenge.id)
                    }
                }

                Divider()

                Button {
                    selectedFilter = .noChallenge
                } label: {
                    Label("Без челленджа", systemImage: "tray")
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

    private var dashboardTitle: String {
        if isMonthCalendarPresented {
            return monthTitle(for: visibleMonthDate)
        }

        if isCurrentWeekSelected {
            return "Эта неделя"
        }

        return weekRangeTitle(for: selectedWeekStart)
    }

    private var isCurrentWeekSelected: Bool {
        calendar.isDate(selectedWeekStart, inSameDayAs: calendar.startOfWeek(for: Date()))
    }

    private var shouldShowCurrentWeekButton: Bool {
        !isCurrentWeekSelected ||
        (isMonthCalendarPresented && !calendar.isDate(visibleMonthDate, equalTo: Date(), toGranularity: .month))
    }

    private func toggleMonthCalendar() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            if !isMonthCalendarPresented {
                visibleMonthDate = calendar.startOfMonth(for: selectedWeekStart)
            }
            isMonthCalendarPresented.toggle()
        }
    }

    private func selectCurrentWeek() {
        let currentWeekStart = calendar.startOfWeek(for: Date())
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            selectedWeekStart = currentWeekStart
            visibleMonthDate = calendar.startOfMonth(for: Date())
            isMonthCalendarPresented = false
        }
    }

    private var monthCalendar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button {
                    shiftVisibleMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Предыдущий месяц")

                Spacer()

                Text(monthYearTitle(for: visibleMonthDate))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Spacer()

                Button {
                    shiftVisibleMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Следующий месяц")
            }

            HStack(spacing: 6) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppPalette.muted)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 6) {
                ForEach(Array(monthWeeks.enumerated()), id: \.offset) { pair in
                    monthWeekRow(pair.element)
                }
            }
        }
        .weeklyPanelStyle()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func monthWeekRow(_ week: [Date]) -> some View {
        let weekStart = week.first.map { calendar.startOfWeek(for: $0) } ?? visibleMonthDate
        let isSelected = calendar.isDate(weekStart, inSameDayAs: selectedWeekStart)

        return HStack(spacing: 6) {
            ForEach(week, id: \.self) { date in
                monthDayButton(date)
            }
        }
        .padding(4)
        .background(isSelected ? AppPalette.accentSoft : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? AppPalette.accent : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func monthDayButton(_ date: Date) -> some View {
        let isInVisibleMonth = calendar.isDate(date, equalTo: visibleMonthDate, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        let summary = monthEntrySummary(on: date)

        return Button {
            selectWeek(containing: date)
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 13, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isInVisibleMonth ? AppPalette.ink : AppPalette.muted.opacity(0.6))
                    .frame(maxWidth: .infinity)

                Circle()
                    .fill(summary.color)
                    .frame(width: 5, height: 5)
                    .opacity(summary == .empty ? 0 : (isInVisibleMonth ? 1 : 0.45))
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isToday ? AppPalette.surface : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isToday ? AppPalette.accent : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .opacity(isInVisibleMonth ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выбрать неделю с \(date.formatted(.dateTime.day().month(.wide)))")
    }

    private var monthWeeks: [[Date]] {
        let monthStart = calendar.startOfMonth(for: visibleMonthDate)
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return []
        }

        var weeks: [[Date]] = []
        var weekStart = calendar.startOfWeek(for: monthStart)
        let lastWeekStart = calendar.startOfWeek(for: monthEnd)

        while weekStart <= lastWeekStart {
            let week = (0..<7).compactMap {
                calendar.date(byAdding: .day, value: $0, to: weekStart)
            }
            weeks.append(week)
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                break
            }
            weekStart = nextWeek
        }

        return weeks
    }

    private func selectWeek(containing date: Date) {
        let weekStart = calendar.startOfWeek(for: date)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            selectedWeekStart = weekStart
            visibleMonthDate = calendar.startOfMonth(for: date)
            isMonthCalendarPresented = false
        }
    }

    private func shiftVisibleMonth(by offset: Int) {
        guard let month = calendar.date(byAdding: .month, value: offset, to: visibleMonthDate) else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            visibleMonthDate = calendar.startOfMonth(for: month)
        }
    }

    private func monthEntrySummary(on date: Date) -> MonthEntrySummary {
        let statuses = rows.compactMap { entry(for: $0.habit, on: date)?.status }
        if statuses.contains(.failed) {
            return .failed
        }
        if statuses.contains(.done) {
            return .done
        }
        if statuses.contains(.skipped) {
            return .skipped
        }
        return .empty
    }

    private func monthTitle(for date: Date) -> String {
        formatted(date, pattern: "LLLL")
    }

    private func monthYearTitle(for date: Date) -> String {
        formatted(date, pattern: "LLLL yyyy")
    }

    private func weekRangeTitle(for startDate: Date) -> String {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let startDay = calendar.component(.day, from: start)
        let endDay = calendar.component(.day, from: end)

        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(startDay)-\(endDay) \(monthTitle(for: end))"
        }

        return "\(startDay) \(formatted(start, pattern: "LLL")) - \(endDay) \(formatted(end, pattern: "LLL"))"
    }

    private func formatted(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
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
                                color: Color(hex: colorHex(for: row)),
                                isToday: calendar.isDateInToday(date),
                                isHighlighted: isHighlighted(row)
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
        .background(calendar.isDateInToday(date) ? AppPalette.accentSoft : AppPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(calendar.isDateInToday(date) ? AppPalette.accent : AppPalette.line, lineWidth: 1)
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
            .background(Color(hex: colorHex(for: row)).opacity(isHighlighted(row) ? 0.18 : 0.06))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: colorHex(for: row)))
                    .frame(width: 5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHighlighted(row) ? Color(hex: colorHex(for: row)) : AppPalette.line, lineWidth: isHighlighted(row) ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                AppHaptics.habitSelected()
                sheet = .editHabit(row.habit)
            }
            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 10, pressing: { isPressing in
                updateChallengePressFeedback(isPressing, for: row)
            }) {
                guard let challenge = row.challenge else { return }
                stopChallengePressFeedback()
                AppHaptics.challengeSelected()
                withAnimation(.easeInOut(duration: 0.16)) {
                    highlightedChallengeID = challenge.id
                }
                sheet = .editChallenge(challenge)
            }
    }

    private func updateChallengePressFeedback(_ isPressing: Bool, for row: WeeklyHabitRow) {
        guard row.challenge != nil else { return }
        if isPressing {
            startChallengePressFeedback()
        } else {
            stopChallengePressFeedback()
        }
    }

    private func startChallengePressFeedback() {
        stopChallengePressFeedback()
        challengePressFeedbackTask = Task { @MainActor in
            for intensity in [0.12, 0.24, 0.4] {
                guard !Task.isCancelled else { return }
                AppHaptics.challengePressProgress(intensity: intensity)
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func stopChallengePressFeedback() {
        challengePressFeedbackTask?.cancel()
        challengePressFeedbackTask = nil
    }

    private func colorHex(for row: WeeklyHabitRow) -> String {
        row.challenge?.colorHex ?? row.habit.colorHex
    }

    private func isHighlighted(_ row: WeeklyHabitRow) -> Bool {
        row.challenge?.id == highlightedChallengeID
    }

    private var filterTitle: String {
        switch selectedFilter {
        case .all:
            return "\(visibleChallenges.count) \(challengeWord(visibleChallenges.count))"
        case .challenge(let id):
            return activeChallenges.first { $0.id == id }?.title ?? "Челлендж"
        case .noChallenge:
            return "Без челленджа"
        }
    }

    private func rows(for challenge: Challenge) -> [WeeklyHabitRow] {
        challenge.habits
            .filter {
                !$0.isArchived &&
                $0.deletedAt == nil &&
                wasCreatedBySelectedWeek($0.createdAt)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { WeeklyHabitRow(challenge: challenge, habit: $0) }
    }

    private func wasCreatedBySelectedWeek(_ createdAt: Date) -> Bool {
        calendar.startOfDay(for: createdAt) <= selectedWeekEnd
    }

    private func isActiveDuringSelectedWeek(_ challenge: Challenge) -> Bool {
        let challengeStart = calendar.startOfDay(for: challenge.startDate)
        let challengeEnd = calendar.startOfDay(for: challenge.endDate)

        if challenge.isTimeless {
            return challengeStart <= selectedWeekEnd
        }

        return challengeStart <= selectedWeekEnd && challengeEnd >= selectedWeekStart
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
        let normalizedDate = calendar.startOfDay(for: date)
        guard calendar.startOfDay(for: habit.createdAt) <= normalizedDate else {
            return false
        }

        switch habit.scheduleMode {
        case .days:
            return habit.scheduledWeekdays.contains(calendar.mondayWeekdayIndex(for: date))
        case .count:
            return plannedDatesForWeeklyTarget(habit).contains(calendar.startOfDay(for: date))
        }
    }

    private func plannedDatesForWeeklyTarget(_ habit: Habit) -> Set<Date> {
        let target = min(max(habit.weeklyTarget, 1), weekDates.count)
        let completedThisWeek = weekDates.filter {
            entry(for: habit, on: $0)?.status == .done
        }.count
        let remainingTarget = max(target - completedThisWeek, 0)
        guard remainingTarget > 0 else { return [] }

        let today = calendar.startOfDay(for: Date())
        let selectedWeekIsCurrent = calendar.isDate(selectedWeekStart, inSameDayAs: calendar.startOfWeek(for: Date()))
        let habitStartDate = calendar.startOfDay(for: habit.createdAt)
        let candidates = weekDates
            .map { calendar.startOfDay(for: $0) }
            .filter { date in
                date >= habitStartDate &&
                (!selectedWeekIsCurrent || date >= today) &&
                entry(for: habit, on: date) == nil
            }

        return Set(candidates.prefix(remainingTarget))
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
            clearStatus(for: habit, on: date)
        } else {
            setStatus(.done, for: habit, on: date)
        }
    }

    private func setStatus(_ status: HabitEntryStatus, for habit: Habit, on date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        let existingEntry = entry(for: habit, on: normalizedDate)
        let shouldPlayCompletionHaptic = status == .done && existingEntry?.status != .done

        if let existing = existingEntry {
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
        if shouldPlayCompletionHaptic {
            AppHaptics.habitCompleted()
        }
    }

    private func clearStatus(for habit: Habit, on date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard let existing = entry(for: habit, on: normalizedDate) else { return }
        existing.markDeleted()
        habit.touch()
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

private enum MonthEntrySummary: Equatable {
    case done
    case failed
    case skipped
    case empty

    var color: Color {
        switch self {
        case .done:
            return AppPalette.accent
        case .failed:
            return AppPalette.warning
        case .skipped:
            return AppPalette.sun
        case .empty:
            return Color.clear
        }
    }
}

private enum CreateAction {
    case habit
    case challenge

    var title: String {
        switch self {
        case .habit: return "Привычку"
        case .challenge: return "Челлендж"
        }
    }

    var systemImage: String {
        switch self {
        case .habit: return "checkmark.circle"
        case .challenge: return "flag"
        }
    }
}

private enum DashboardSheet: Identifiable {
    case newHabit
    case newChallenge
    case editHabit(Habit)
    case editChallenge(Challenge)

    var id: String {
        switch self {
        case .newHabit: return "newHabit"
        case .newChallenge: return "newChallenge"
        case .editHabit(let habit): return "editHabit-\(habit.id)"
        case .editChallenge(let challenge): return "editChallenge-\(challenge.id)"
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
    let isHighlighted: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border, lineWidth: isHighlighted || isToday ? 1.5 : 1)
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
            return color.opacity(isHighlighted ? 0.32 : (isToday ? 0.26 : 0.18))
        case .rest:
            if isHighlighted {
                return color.opacity(0.13)
            }
            return AppPalette.surface.opacity(0.42)
        }
    }

    private var border: Color {
        if isHighlighted {
            return color
        }

        if isToday {
            return AppPalette.accent
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
    let habit: Habit?

    @State private var selectedChallengeID: UUID?
    @State private var title: String
    @State private var note: String
    @State private var colorHex: String
    @State private var scheduleMode: HabitScheduleMode
    @State private var scheduledWeekdays: Set<Int>
    @State private var weeklyTarget: Int
    @State private var selectedReminderTime: Date
    @State private var reminderTimes: Set<String>
    @State private var isDeleteConfirmationPresented = false

    private let weekdays = [
        (1, "ПН"),
        (2, "ВТ"),
        (3, "СР"),
        (4, "ЧТ"),
        (5, "ПТ"),
        (6, "СБ"),
        (7, "ВС")
    ]
    private var selectedChallenge: Challenge? {
        challenges.first { $0.id == selectedChallengeID }
    }

    private var isEditing: Bool {
        habit != nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (scheduleMode == .count || !scheduledWeekdays.isEmpty)
    }

    init(challenges: [Challenge], habit: Habit? = nil) {
        self.challenges = challenges
        self.habit = habit

        _selectedChallengeID = State(initialValue: habit?.challenge?.id)
        _title = State(initialValue: habit?.title ?? "Читать 20 минут")
        _note = State(initialValue: habit?.note ?? "Перед сном, без телефона рядом. Если день сложный, достаточно 10 минут.")
        _colorHex = State(initialValue: habit?.colorHex ?? HabitColor.sage.rawValue)
        _scheduleMode = State(initialValue: habit?.scheduleMode ?? .days)
        _scheduledWeekdays = State(initialValue: habit?.scheduledWeekdays ?? [2, 4, 7])
        _weeklyTarget = State(initialValue: habit?.weeklyTarget ?? 3)

        let reminders = Set(habit?.reminderTimes ?? ["20:00"])
        _reminderTimes = State(initialValue: reminders)
        _selectedReminderTime = State(initialValue: HabitFormView.reminderDate(from: reminders.sorted().first ?? "20:00"))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(isEditing ? "Редактирование привычки" : "Новая привычка")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.muted)

                formPanel
                schedulePanel
                reminderPanel

                Button(isEditing ? "Сохранить изменения" : "Сохранить привычку") {
                    saveHabit()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)

                if isEditing {
                    Button("Удалить привычку", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppPalette.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
        .alert("Удалить привычку?", isPresented: $isDeleteConfirmationPresented) {
            Button("Удалить", role: .destructive) {
                deleteHabit()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все отметки этой привычки тоже будут удалены.")
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

            if let selectedChallenge {
                labeledField("Цвет") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: selectedChallenge.colorHex))
                            .frame(width: 30, height: 30)
                        Text("Цвет челленджа")
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.muted)
                    }
                }
            } else {
                labeledField("Цвет") {
                    colorPicker
                }
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

            DatePicker(
                "Время",
                selection: $selectedReminderTime,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 136)
            .clipped()

            HStack {
                Text(timeString(from: selectedReminderTime))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Button("Добавить") {
                    reminderTimes.insert(timeString(from: selectedReminderTime))
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if !reminderTimes.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(reminderTimes.sorted(), id: \.self) { time in
                        Button {
                            reminderTimes.remove(time)
                        } label: {
                            HStack(spacing: 5) {
                                Text(time)
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppPalette.accent)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(AppPalette.accentSoft)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AppPalette.accent, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .weeklyPanelStyle()
    }

    private func timeString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private static func reminderDate(from time: String) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = parts.first.map { min(max($0, 0), 23) } ?? 20
        components.minute = parts.dropFirst().first.map { min(max($0, 0), 59) } ?? 0
        return components.date ?? Date()
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
        let challenge = selectedChallenge
        let notificationPlan: HabitNotificationScheduler.Plan

        let isNewHabit = habit == nil

        if let habit {
            let oldChallenge = habit.challenge
            let didChangeChallenge = oldChallenge?.id != challenge?.id
            let updatedSortOrder = didChangeChallenge ? nextSortOrder(for: challenge) : habit.sortOrder
            habit.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.penaltyText = ""
            habit.colorHex = challenge?.colorHex ?? colorHex
            habit.scheduleMode = scheduleMode
            habit.scheduledWeekdays = scheduledWeekdays
            habit.weeklyTarget = weeklyTarget
            habit.reminderTimes = reminderTimes.sorted()
            habit.challenge = challenge
            habit.userId = challenge?.user?.id ?? habit.userId
            habit.sortOrder = updatedSortOrder
            habit.touch()
            oldChallenge?.touch()
            challenge?.touch()
            notificationPlan = HabitNotificationScheduler.plan(for: habit)
        } else {
            let habit = Habit(
                userId: challenge?.user?.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                penaltyText: "",
                colorHex: challenge?.colorHex ?? colorHex,
                scheduleMode: scheduleMode,
                scheduledWeekdays: scheduledWeekdays,
                weeklyTarget: weeklyTarget,
                reminderTimes: reminderTimes.sorted(),
                sortOrder: nextSortOrder(for: challenge),
                challenge: challenge
            )
            if let challenge {
                challenge.habits.append(habit)
                challenge.touch()
            }
            modelContext.insert(habit)
            notificationPlan = HabitNotificationScheduler.plan(for: habit)
        }

        try? modelContext.save()
        Task {
            await HabitNotificationScheduler.shared.scheduleNotifications(for: notificationPlan)
        }
        if isNewHabit {
            AppHaptics.itemAdded()
        }
        dismiss()
    }

    private func nextSortOrder(for challenge: Challenge?) -> Int {
        if let challenge {
            return (challenge.habits.map(\.sortOrder).max() ?? -1) + 1
        }
        return 0
    }

    private func deleteHabit() {
        guard let habit else { return }
        let challenge = habit.challenge
        let habitID = habit.id
        habit.markDeleted()
        challenge?.touch()
        try? modelContext.save()
        Task {
            await HabitNotificationScheduler.shared.removeNotifications(forHabitID: habitID)
        }
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
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components).map(startOfDay(for:)) ?? startOfDay(for: date)
    }

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

func hideKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}
