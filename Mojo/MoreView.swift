import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            Text("More View")
                .navigationTitle("More")
        }
    }
}

#if DEBUG
struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
#endif 