import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("Home View")
                .navigationTitle("Home")
        }
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
#endif 