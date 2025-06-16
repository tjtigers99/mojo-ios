import Supabase
import SwiftUI

struct ContentView: View {
    @State private var todos: [Todo] = []
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if isLoggedIn {
                List(todos) { todo in
                    Text(todo.title)
                }
                .navigationTitle("Todos")
                .toolbar {
                    Button("Logout", action: signOut)
                }
                .task {
                    await loadTodos()
                }
            } else {
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                    Button("Sign In", action: signIn)
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("Login")
            }
        }
    }

    private func loadTodos() async {
        do {
            todos = try await supabase.from("todos").select().execute().value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signIn() {
        Task {
            do {
                try await supabase.auth.signIn(email: email, password: password)
                isLoggedIn = true
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                isLoggedIn = false
                todos = []
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
