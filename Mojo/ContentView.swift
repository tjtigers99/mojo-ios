import Supabase
import SwiftUI

struct ContentView: View {
    @State var todos: [Todo] = []
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        NavigationStack {
            List(todos) { todo in
                Text(todo.title)
            }
            .navigationTitle("Todos")
            .toolbar {
                Button("Sign Out") {
                    Task { await signOut() }
                }
            }
            .task {
                do {
                    todos = try await supabase.from("habits").select().execute().value
                } catch {
                    debugPrint(error)
                }
            }
        }
    }

    @MainActor
    private func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            debugPrint("Sign out error: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionManager())
}
