import SwiftUI

struct Habit: Identifiable {
    let id = UUID()
    var name: String
    var isCompleted: Bool
    var streak: Int
}

struct HabitTracker: View {
    @State private var habits: [Habit] = [
        Habit(name: "Exercise", isCompleted: false, streak: 0),
        Habit(name: "Read", isCompleted: false, streak: 0),
        Habit(name: "Meditate", isCompleted: false, streak: 0)
    ]
    @State private var newHabitName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Habit Tracker")
                .font(.largeTitle)
                .bold()
            
            HStack {
                TextField("New habit", text: $newHabitName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addHabit) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            ForEach(habits) { habit in
                HStack {
                    Button(action: { toggleHabit(habit) }) {
                        Image(systemName: habit.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(habit.isCompleted ? .green : .gray)
                    }
                    
                    Text(habit.name)
                        .strikethrough(habit.isCompleted)
                    
                    Spacer()
                    
                    Text("🔥 \(habit.streak)")
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
    }
    
    private func addHabit() {
        guard !newHabitName.isEmpty else { return }
        habits.append(Habit(name: newHabitName, isCompleted: false, streak: 0))
        newHabitName = ""
    }
    
    private func toggleHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].isCompleted.toggle()
            if habits[index].isCompleted {
                habits[index].streak += 1
            }
        }
    }
}

#Preview {
    HabitTracker()
} 