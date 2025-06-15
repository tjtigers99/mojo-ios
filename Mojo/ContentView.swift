//
//  ContentView.swift
//  Mojo
//
//  Created by Tyler Bullock on 6/15/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            HabitTracker()
                .navigationTitle("Mojo")
        }
    }
}

#Preview {
    ContentView()
}
