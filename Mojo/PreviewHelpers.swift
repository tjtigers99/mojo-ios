import SwiftUI
import Supabase

// MARK: - Preview Helpers

#if DEBUG
/// Creates a mock SessionManager with a valid authenticated session for previews
struct MockSessionManager {
    @MainActor static func create() -> SessionManager {
        let mockSessionManager = SessionManager()
        
        // Create a mock User
        let mockUser = User(
            id: UUID(),
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Create a mock Session
        let mockSession = Session(
            providerToken: nil,
            providerRefreshToken: nil,
            accessToken: "mock_access_token",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "mock_refresh_token",
            weakPassword: nil,
            user: mockUser
        )
        
        // Set the session on the mock SessionManager
        mockSessionManager.session = mockSession
        
        return mockSessionManager
    }
}

/// A view modifier that provides a mock SessionManager for previews
struct MockSessionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environmentObject(MockSessionManager.create())
    }
}

/// Extension to make it easy to apply the mock session to any view
extension View {
    /// Applies a mock SessionManager for previews
    func mockSession() -> some View {
        self.modifier(MockSessionModifier())
    }
}
#endif 