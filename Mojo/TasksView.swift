import SwiftUI

struct TasksView: View {
    var body: some View {
        NavigationStack {
            Text("Tasks View")
                .navigationTitle("Tasks")
        }
    }
}

#if DEBUG
struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
    }
}
#endif 