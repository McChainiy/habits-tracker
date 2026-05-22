import SwiftData
import SwiftUI

struct MonthDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var challenge: Challenge

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    private var orderedHabits: [Habit] {
        challenge.habits
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var monthDates: [Date] {
        guard
            let start = calendar.date(from: DateComponents(year: challenge.year, month: challenge.month, day: 1)),
            let range = calendar.range(of: .day, in: .month, for: start)
        else {
            return []
        }

        return range.compactMap {
            calendar.date(from: DateComponents(year: challenge.year, month: challenge.month, day: $0))
        }
    }

    private var leadingEmptyDays: Int {
        guard let first = monthDates.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday + 5) % 7
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                habitChips
                calendarGrid
                checkIn
            }
            .padding(18)
        }
        .background(AppPalette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Текущий месяц")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.muted)
                Text(challenge.title.capitalized)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            Spacer()
            Text("\(orderedHabits.count)/5")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.muted)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(AppPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppPalette.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var habitChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(orderedHabits, id: \.id) { habit in
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Color(hex: habit.colorHex))
                            .frame(width: 8, height: 8)
                        Text(habit.title)
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.muted)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(AppPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppPalette.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppPalette.muted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }

                ForEach(monthDates, id: \.self) { date in
                    Button {
                        selectedDate = calendar.startOfDay(for: date)
                    } label: {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            habits: orderedHabits,
                            entryStatus: { habit in
                                entry(for: habit, on: date)?.status
                            }
                        )
                    }
                    .buttonStyle(.plain)
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

    private var checkIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(selectedDate.formatted(.dateTime.day().month(.wide)))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .padding(.bottom, 10)

            ForEach(orderedHabits, id: \.id) { habit in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(habit.title)
                            .font(.system(size: 16))
                            .foregroundStyle(AppPalette.ink)
                        Spacer()
                        statusButton("✓", status: .done, habit: habit)
                        statusButton("×", status: .failed, habit: habit)
                    }

                    if entry(for: habit, on: selectedDate)?.status == .failed {
                        Text("Наказание: \(habit.penaltyText)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.warning)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppPalette.warningSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppPalette.line.opacity(0.8))
                        .frame(height: 1)
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

    private func statusButton(_ title: String, status: HabitEntryStatus, habit: Habit) -> some View {
        let isActive = entry(for: habit, on: selectedDate)?.status == status
        return Button {
            setStatus(status, for: habit, on: selectedDate)
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? AppPalette.surface : AppPalette.ink)
                .frame(width: 34, height: 34)
                .background(isActive ? AppPalette.accent : AppPalette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActive ? AppPalette.accent : AppPalette.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        let normalizedDate = calendar.startOfDay(for: date)
        return habit.entries.first {
            calendar.isDate($0.entryDate, inSameDayAs: normalizedDate)
        }
    }

    private func setStatus(_ status: HabitEntryStatus, for habit: Habit, on date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)

        if let existing = entry(for: habit, on: normalizedDate) {
            existing.status = status
        } else {
            let entry = HabitEntry(
                userId: challenge.user?.id ?? habit.userId,
                entryDate: normalizedDate,
                status: status,
                habit: habit
            )
            habit.entries.append(entry)
            modelContext.insert(entry)
        }

        try? modelContext.save()
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let habits: [Habit]
    let entryStatus: (Habit) -> HabitEntryStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppPalette.ink : AppPalette.muted)

            HStack(spacing: 2) {
                ForEach(habits.prefix(5), id: \.id) { habit in
                    Circle()
                        .fill(color(for: entryStatus(habit), habit: habit))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .padding(6)
        .background(isSelected ? AppPalette.accent.opacity(0.16) : AppPalette.paper.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isSelected ? AppPalette.accent : AppPalette.line.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func color(for status: HabitEntryStatus?, habit: Habit) -> Color {
        switch status {
        case .done:
            return Color(hex: habit.colorHex)
        case .failed:
            return AppPalette.warning
        case .skipped, .none:
            return AppPalette.line
        }
    }
}
