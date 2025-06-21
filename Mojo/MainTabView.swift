import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            HabitTracker()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle")
                }
            
            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "list.clipboard")
                }
            
            CheckInsView()
                .tabItem {
                    Label("Check-Ins", systemImage: "face.smiling")
                }

            MoreView()
                .tabItem {
                    Label("More", systemImage: "line.3.horizontal")
                }
        }
    }
}

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SessionManager())
    }
}
#endif 