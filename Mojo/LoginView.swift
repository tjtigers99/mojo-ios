import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var sessionManager: SessionManager
    @State private var loginError: String?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            Button("Sign In") {
                Task { await signIn() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .alert("Login Error", isPresented: .constant(loginError != nil), actions: {
            Button("OK", role: .cancel) { loginError = nil }
        }, message: {
            if let loginError { Text(loginError) }
        })
    }

    @MainActor
    private func signIn() async {
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            loginError = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
