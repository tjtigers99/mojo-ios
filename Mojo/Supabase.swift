import Foundation

/// Minimal helper for interacting with Supabase using raw HTTP requests.
/// This avoids requiring the `Supabase` Swift package so the project builds
/// without additional dependencies.
enum SupabaseAPI {
    static let url = URL(string: "https://utlrtdwxjyjmlpzbyfgx.supabase.co")!
    /// Replace with your project's anon key.
    static let apiKey = "YOUR_SUPABASE_ANON_KEY"

    /// Response structure returned by the Supabase auth endpoint.
    private struct TokenResponse: Decodable { let access_token: String }

    /// Sign in a user with email and password and return the access token.
    static func signIn(email: String, password: String) async throws -> String {
        let signInURL = url
            .appendingPathComponent("auth")
            .appendingPathComponent("v1")
            .appendingPathComponent("token")
            .appending(queryItems: [
                URLQueryItem(name: "grant_type", value: "password")
            ])

        var request = URLRequest(url: signInURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data).access_token
    }

    /// Fetch all todos using the provided access token.
    static func fetchTodos(accessToken: String) async throws -> [Todo] {
        let todosURL = url
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
            .appendingPathComponent("todos")

        var request = URLRequest(url: todosURL)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([Todo].self, from: data)
    }
}

