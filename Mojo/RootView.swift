import SwiftUI

struct RootView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        Group {
            if sessionManager.session == nil {
                LoginView()
            } else {
                MainTabView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
}
