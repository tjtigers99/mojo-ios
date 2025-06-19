import SwiftUI

struct RootView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        Group {
            if sessionManager.session == nil {
                LoginView()
            } else {
                HabitTracker()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
}
