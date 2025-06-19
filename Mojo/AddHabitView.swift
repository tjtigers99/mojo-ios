import SwiftUI
import Supabase

struct AddHabitView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager

    var onAdd: (Habit) -> Void

    @State private var name: String = ""
    @State private var frequency: String = "daily"
    @State private var goal: String = "1"
    @State private var priority: Int = 1
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Habit")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            VStack(alignment: .leading, spacing: 15) {
                TextField("Habit name", text: $name)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )

                HStack {
                    Picker(selection: $frequency, label: Text("Frequency")) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )

                    TextField("Goal", text: $goal)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                        )
                }

                HStack(spacing: 15) {
                    ForEach(1...3, id: \.self) { p in
                        Button(action: { self.priority = p }) {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                                .foregroundColor(p <= self.priority ? .green : Color.gray.opacity(0.3))
                        }
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: {
                    Task { await createHabit() }
                }) {
                    Text(isSaving ? "Creating..." : "Create Habit")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || Int(goal) == nil)

                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .background(Color.purple.opacity(0.05).ignoresSafeArea())
    }

    private func createHabit() async {
        guard let goalInt = Int(goal), let userId = sessionManager.session?.user.id else {
            errorMessage = "Invalid goal. Please enter a number."
            return
        }
        
        isSaving = true
        errorMessage = nil

        struct NewHabitPayload: Encodable {
            let user_id: UUID
            let name: String
            let frequency: String
            let goal: Int
            let priority: Int
        }

        let payload = NewHabitPayload(
            user_id: userId,
            name: name,
            frequency: frequency,
            goal: goalInt,
            priority: priority
        )

        do {
            let newHabit: Habit = try await supabase.from("habits")
                .insert(payload, returning: .representation)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                onAdd(newHabit)
                dismiss()
            }
        } catch {
            errorMessage = "Failed to create habit. Please ensure you have added a 'priority' column (type: int4) to your 'habits' table."
            print("Error creating habit: \(error)")
        }
        
        isSaving = false
    }
}

#if DEBUG
struct AddHabitView_Previews: PreviewProvider {
    static var previews: some View {
        AddHabitView(onAdd: { _ in })
            .environmentObject(SessionManager())
    }
}
#endif 