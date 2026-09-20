import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Kezdőlap", systemImage: "house.fill") }

            CalendarView()
                .tabItem { Label("Naptár", systemImage: "calendar") }

            MembersView()
                .tabItem { Label("Tagok", systemImage: "person.3.fill") }

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .environmentObject(store)
        .tint(.blue)
    }
}
