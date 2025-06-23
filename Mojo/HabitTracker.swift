import SwiftUI
import Supabase

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let frequency: String
    let goal: Int
    let priority: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, frequency, goal, priority
    }
}

struct LogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let habitId: UUID
    let date: String
    let completions: Int

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case date
        case completions
    }
}

struct HabitTracker: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var habits: [Habit] = []
    @State private var progress: [UUID: Int] = [:]
    @State private var weeklyDisplayProgress: [UUID: Int] = [:]
    @State private var totalProgress: [UUID: Int] = [:]
    @State private var currentDate = Date()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isShowingAddHabitSheet = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }

    private var queryDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                headerView

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else {
                    todaysProgressView
                }
            }
            .navigationTitle("Your Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddHabitSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Habit")
                        }
                    }
                    .tint(.green)
                    .buttonStyle(.borderedProminent)
                }
            }
            .task {
                await loadInitialData()
            }
            .onChange(of: currentDate) {
                Task {
                    await fetchLogEntries(for: currentDate)
                }
            }
            .sheet(isPresented: $isShowingAddHabitSheet) {
                AddHabitView { newHabit in
                    habits.append(newHabit)
                    progress[newHabit.id] = 0
                }
                .environmentObject(sessionManager)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Your Habits")
                .font(.largeTitle)
                .bold()
                .padding(.leading)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var todaysProgressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            dateSelectorView
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(habits) { habit in
                        let displayProgress = habit.frequency == "weekly"
                            ? weeklyDisplayProgress[habit.id, default: 0]
                            : progress[habit.id, default: 0]

                        HabitRow(
                            habit: habit,
                            displayProgress: displayProgress,
                            totalProgress: totalProgress[habit.id, default: 0],
                            onIncrement: {
                                incrementHabit(for: habit)
                            },
                            onDecrement: {
                                decrementHabit(for: habit)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var dateSelectorView: some View {
        HStack {
            Image(systemName: "calendar")
            Text("Today's Progress")
                .font(.headline)
            Spacer()
            Button(action: {
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? Date()
            }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(dateFormatter.string(from: currentDate))
                .font(.subheadline)
                .frame(minWidth: 150)

            Button(action: {
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? Date()
            }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private func incrementHabit(for habit: Habit) {
        updateHabitProgress(for: habit, with: 1)
    }

    private func decrementHabit(for habit: Habit) {
        guard let dailyProgress = progress[habit.id], dailyProgress > 0 else { return }
        updateHabitProgress(for: habit, with: -1)
    }

    private func updateHabitProgress(for habit: Habit, with diff: Int) {
        let habitId = habit.id

        let newDailyValue = (progress[habitId] ?? 0) + diff
        progress[habitId] = newDailyValue

        if habit.frequency == "weekly" {
            weeklyDisplayProgress[habitId, default: 0] += diff
        }

        totalProgress[habitId, default: 0] += diff

        Task {
            await updateLogEntry(for: habitId, completions: newDailyValue)
        }
    }

    private func loadInitialData() async {
        isLoading = true
        await fetchHabits()
        await fetchAllTimeProgress()
        await fetchLogEntries(for: currentDate)
        isLoading = false
    }

    private func fetchHabits() async {
        guard let userId = sessionManager.session?.user.id else {
            errorMessage = "You must be logged in to see your habits."
            isLoading = false
            return
        }

        errorMessage = nil
        do {
            let fetchedHabits: [Habit] = try await supabase.from("habits")
                .select()
                .eq("user_id", value: userId)
                .eq("is_archived", value: false)
                .execute()
                .value

            self.habits = fetchedHabits
            self.progress = [:]
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching habits: \(error)")
        }
    }

    private func fetchAllTimeProgress() async {
        guard let userId = sessionManager.session?.user.id else { return }
        
        do {
            let allEntries: [LogEntry] = try await supabase.from("log_entries")
                .select("id, habit_id, date, completions")
                .eq("user_id", value: userId)
                .execute()
                .value

            let progressByHabit = Dictionary(grouping: allEntries, by: { $0.habitId })
                .mapValues { entries in entries.reduce(0) { $0 + $1.completions } }
            
            self.totalProgress = progressByHabit
            
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching all-time progress: \(error)")
        }
    }

    private func fetchLogEntries(for date: Date) async {
        guard let userId = sessionManager.session?.user.id else {
            errorMessage = "You must be logged in to see your progress."
            return
        }

        guard let weekStart = date.startOfWeek, let weekEnd = date.endOfWeek else {
            errorMessage = "Could not determine week boundaries."
            return
        }

        let weekStartDateString = queryDateFormatter.string(from: weekStart)
        let weekEndDateString = queryDateFormatter.string(from: weekEnd)
        let selectedDateString = queryDateFormatter.string(from: date)

        var newProgress = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, 0) })
        var newWeeklyDisplayProgress = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, 0) })

        do {
            let entries: [LogEntry] = try await supabase.from("log_entries")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: weekStartDateString)
                .lte("date", value: weekEndDateString)
                .execute()
                .value

            let entriesByHabit = Dictionary(grouping: entries, by: { $0.habitId })
            let habitsById = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })

            for (habitId, _) in newProgress {
                guard let habit = habitsById[habitId] else { continue }

                let habitEntries = entriesByHabit[habitId] ?? []

                if let dailyEntry = habitEntries.first(where: { $0.date == selectedDateString }) {
                    newProgress[habitId] = dailyEntry.completions
                }

                if habit.frequency == "weekly" {
                    let weeklyTotal = habitEntries.reduce(0) { $0 + $1.completions }
                    newWeeklyDisplayProgress[habitId] = weeklyTotal
                }
            }

            self.progress = newProgress
            self.weeklyDisplayProgress = newWeeklyDisplayProgress
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching log entries: \(error)")
        }
    }

    private func updateLogEntry(for habitId: UUID, completions: Int) async {
        guard let userId = sessionManager.session?.user.id else {
            errorMessage = "You must be logged in to update progress."
            return
        }

        let dateString = queryDateFormatter.string(from: currentDate)

        struct LogEntryPayload: Encodable {
            var habit_id: UUID
            var user_id: UUID
            var date: String
            var completions: Int
        }

        let payload = LogEntryPayload(
            habit_id: habitId,
            user_id: userId,
            date: dateString,
            completions: completions
        )

        do {
            try await supabase.from("log_entries")
                .upsert(payload, onConflict: "habit_id,user_id,date")
                .execute()
        } catch {
            errorMessage = error.localizedDescription
            print("Error updating log entry: \(error)")
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    let displayProgress: Int
    let totalProgress: Int
    var onIncrement: () -> Void
    var onDecrement: () -> Void
    @State private var wavePhaseRadians: Double = 0.0

    var body: some View {
        ZStack {
            LiquidWave(
                progress: fillProgress,
                waveAmplitude: 5,
                waveFrequency: 2,
                phaseRadians: wavePhaseRadians
            )
            .fill(liquidColor.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 15))

            HStack {
                VStack(alignment: .leading) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    Text(habit.frequency)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: {
                        onDecrement()
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Text("\(displayProgress)/\(habit.goal)")
                        .font(.body.monospacedDigit().bold())
                        .foregroundColor(.white)
                        .frame(minWidth: 40)

                    Button(action: {
                        onIncrement()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .frame(height: 80)
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhaseRadians = 2 * .pi
            }
        }
    }

    private var fillProgress: CGFloat {
        let progress = CGFloat(totalProgress) / 100.0
        return min(progress, 1.0)
    }

    private var liquidColor: Color {
        switch habit.priority {
        case 1:
            return .blue
        case 2:
            return .orange
        case 3:
            return .red
        default:
            return .green
        }
    }
}

private extension Date {
    var startOfWeek: Date? {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)
    }

    var endOfWeek: Date? {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let startOfWeek = self.startOfWeek else { return nil }
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek)
    }
}


