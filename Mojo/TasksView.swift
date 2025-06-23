import SwiftUI
import Supabase

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

struct MojoTask: Identifiable, Codable, Equatable {
    let id: UUID
    let user_id: UUID
    let name: String
    let status: String
    let priority: Int
    let initial_deadline: Date?
    let date_completed: Date?
    let created_at: Date
    let tags: [String]?

    // Explicit memberwise initializer
    init(id: UUID, user_id: UUID, name: String, status: String, priority: Int, initial_deadline: Date?, date_completed: Date?, created_at: Date, tags: [String]?) {
        self.id = id
        self.user_id = user_id
        self.name = name
        self.status = status
        self.priority = priority
        self.initial_deadline = initial_deadline
        self.date_completed = date_completed
        self.created_at = created_at
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, status, priority, initial_deadline, date_completed, created_at, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        user_id = try container.decode(UUID.self, forKey: .user_id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(String.self, forKey: .status)
        priority = try container.decode(Int.self, forKey: .priority)
        // Custom decode for initial_deadline (yyyy-MM-dd)
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .initial_deadline) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            initial_deadline = formatter.date(from: dateString)
        } else {
            initial_deadline = nil
        }
        // date_completed and created_at: try to decode as ISO8601 (default)
        date_completed = try? container.decodeIfPresent(Date.self, forKey: .date_completed)
        created_at = try container.decode(Date.self, forKey: .created_at)
        tags = try? container.decodeIfPresent([String].self, forKey: .tags)
    }
}

struct TasksView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var tasks: [MojoTask] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isShowingAddTaskSheet = false
    @State private var statusFilter: String = "All"

    private var filteredTasks: [MojoTask] {
        switch statusFilter {
        case "Open":
            return tasks.filter { $0.status.lowercased() == "open" }
        case "Completed":
            return tasks.filter { $0.status.lowercased() == "completed" }
        default:
            return tasks
        }
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
                    tasksListView
                }
            }
            .navigationTitle("Your Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddTaskSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Task")
                        }
                    }
                    .tint(.green)
                    .buttonStyle(.borderedProminent)
                }
            }
            .task {
                await loadTasks()
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                AddTaskView { newTask in
                    tasks.append(newTask)
                }
                .environmentObject(sessionManager)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Your Tasks")
                .font(.largeTitle)
                .bold()
                .padding(.leading)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var tasksListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            filterView
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredTasks) { task in
                        TaskRow(task: task) { completed in
                            Task {
                                await updateTaskCompletion(task, completed: completed)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var filterView: some View {
        HStack {
            Picker("Status", selection: $statusFilter) {
                Text("All").tag("All")
                Text("Open").tag("Open")
                Text("Completed").tag("Completed")
            }
            .pickerStyle(.menu)
            Spacer()
        }
    }

    private func loadTasks() async {
        isLoading = true
        errorMessage = nil
        guard let userId = sessionManager.session?.user.id else {
            errorMessage = "You must be logged in to see your tasks."
            isLoading = false
            return
        }
        do {
            let fetchedTasks: [MojoTask] = try await supabase.from("tasks")
                .select()
                .eq("user_id", value: userId)
                .order("initial_deadline", ascending: true)
                .execute()
                .value
            self.tasks = fetchedTasks
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching tasks: \(error)")
        }
        isLoading = false
    }

    private func updateTaskCompletion(_ task: MojoTask, completed: Bool) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        let nowString = formatter.string(from: now)
        do {
            let updatePayload: [String: AnyEncodable] = [
                "status": AnyEncodable(completed ? "completed" : "open"),
                "date_completed": AnyEncodable(completed ? nowString : nil as String?)
            ]
            let _ = try await supabase.from("tasks")
                .update(updatePayload)
                .eq("id", value: task.id)
                .execute()
            let updated = MojoTask(
                id: task.id,
                user_id: task.user_id,
                name: task.name,
                status: completed ? "completed" : "open",
                priority: task.priority,
                initial_deadline: task.initial_deadline,
                date_completed: completed ? now : nil,
                created_at: task.created_at,
                tags: task.tags
            )
            await MainActor.run {
                tasks[idx] = updated
            }
        } catch {
            print("Error updating task completion: \(error)")
        }
    }
}

struct TaskRow: View {
    let task: MojoTask
    var onToggleComplete: (Bool) -> Void
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let tags = task.tags, !tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.15))
                                    .foregroundColor(.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(task.status.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(task.status.lowercased() == "completed" ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                            .foregroundColor(task.status.lowercased() == "completed" ? .green : .blue)
                            .clipShape(Capsule())
                        if let due = task.initial_deadline {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text(Self.dueDateFormatter.string(from: due))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if task.status.lowercased() == "open" {
                        Button(action: { onToggleComplete(true) }) {
                            Text("Mark Complete")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Button(action: { onToggleComplete(false) }) {
                                Text("Mark Incomplete")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(height: 80)
        .padding(.vertical, 2)
    }
    static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    var onAdd: (MojoTask) -> Void

    @State private var name: String = ""
    @State private var priority: Int = 1
    @State private var dueDate: Date = Date()
    @State private var tagsString: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Task")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            VStack(alignment: .leading, spacing: 15) {
                TextField("Task name", text: $name)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )

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

                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )

                TextField("Tags (comma separated)", text: $tagsString)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )
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
                    Task { await createTask() }
                }) {
                    Text(isSaving ? "Creating..." : "Save Task")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)

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

    private func createTask() async {
        guard let userId = sessionManager.session?.user.id else {
            errorMessage = "You must be logged in."
            return
        }
        isSaving = true
        errorMessage = nil

        struct NewTaskPayload: Encodable {
            let user_id: UUID
            let name: String
            let status: String
            let priority: Int
            let initial_deadline: String
            let tags: [String]?
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let deadlineString = formatter.string(from: dueDate)
        let tagsArray = tagsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let payload = NewTaskPayload(
            user_id: userId,
            name: name,
            status: "open",
            priority: priority,
            initial_deadline: deadlineString,
            tags: tagsArray.isEmpty ? nil : tagsArray
        )

        do {
            let newTask: MojoTask = try await supabase.from("tasks")
                .insert(payload, returning: .representation)
                .select()
                .single()
                .execute()
                .value
            await MainActor.run {
                onAdd(newTask)
                dismiss()
            }
        } catch {
            errorMessage = "Failed to create task. Please try again."
            print("Error creating task: \(error)")
        }
        isSaving = false
    }
}

#if DEBUG
struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
            .environmentObject(SessionManager())
    }
}
#endif 