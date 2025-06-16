import SwiftUI

struct ContentView: View {
    @State private var todos: [Todo] = []
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var accessToken: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if let token = accessToken {
                List(todos) { todo in
                    Text(todo.title)
                }
                .navigationTitle("Todos")
                .toolbar {
                    Button("Logout", action: signOut)
                }
                .task {
                    await loadTodos(token: token)
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

    private func loadTodos(token: String) async {
        do {
            todos = try await SupabaseAPI.fetchTodos(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signIn() {
        Task {
            do {
                let token = try await SupabaseAPI.signIn(email: email, password: password)
                accessToken = token
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signOut() {
        accessToken = nil
        todos = []
    }
}

#Preview {
    ContentView()
}
