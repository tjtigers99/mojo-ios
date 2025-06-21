import SwiftUI

struct CheckInsView: View {
    var body: some View {
        NavigationStack {
            Text("Check-Ins View")
                .navigationTitle("Check-Ins")
        }
    }
}

#if DEBUG
struct CheckInsView_Previews: PreviewProvider {
    static var previews: some View {
        CheckInsView()
    }
}
#endif 