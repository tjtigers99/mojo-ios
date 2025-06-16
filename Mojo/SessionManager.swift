import Foundation
import Supabase
import SwiftUI

@MainActor
final class SessionManager: ObservableObject {
    @Published var session: Session?

    private var handleTask: Task<Void, Never>?

    init() {
        handleTask = Task {
            for await (_, session) in supabase.auth.authStateChanges {
                self.session = session
            }
        }
    }

    deinit {
        handleTask?.cancel()
    }
}
