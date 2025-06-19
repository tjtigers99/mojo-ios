import SwiftUI
import Supabase

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let frequency: String
    let goal: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case frequency
        case goal
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
    @State private var currentDate = Date()
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                        // TODO: Implement Add Habit functionality
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
                        HabitRow(
                            habit: habit,
                            progress: Binding(
                                get: { progress[habit.id, default: 0] },
                                set: { newValue in
                                    progress[habit.id] = newValue
                                    Task {
                                        await updateLogEntry(for: habit.id, completions: newValue)
                                    }
                                }
                            )
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

    private func loadInitialData() async {
        isLoading = true
        await fetchHabits()
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

                if habit.frequency == "weekly" {
                    let weeklyTotal = habitEntries.reduce(0) { $0 + $1.completions }
                    newProgress[habitId] = weeklyTotal
                } else { // "daily"
                    if let dailyEntry = habitEntries.first(where: { $0.date == selectedDateString }) {
                        newProgress[habitId] = dailyEntry.completions
                    }
                }
            }
            
            self.progress = newProgress
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
    @Binding var progress: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(habit.name)
                    .font(.headline)
                Text(habit.frequency)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(habit.frequency == "daily" ? .blue : .green)
                    .background((habit.frequency == "daily" ? Color.blue : Color.green).opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        if progress > 0 { progress -= 1 }
                    }) {
                        Image(systemName: "minus")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(progress)/\(habit.goal)")
                        .font(.body.monospacedDigit())
                        .frame(minWidth: 40)

                    Button(action: {
                        progress += 1
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue.gradient)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ProgressView(value: Double(progress), total: Double(habit.goal))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text(progressText)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(.background)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var progressText: String {
        guard habit.goal > 0 else { return "0% complete" }
        let percentage = Int((Double(progress) / Double(habit.goal)) * 100)
        return "\(percentage)% complete"
    }
}

private extension Date {
    var startOfWeek: Date? {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
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

#if DEBUG
struct HabitTracker_Previews: PreviewProvider {
    static var previews: some View {
        HabitTracker()
            .environmentObject(SessionManager())
    }
}
#endif 