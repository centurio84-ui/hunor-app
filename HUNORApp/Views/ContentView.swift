import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()

    var body: some View {
        Group {
            if store.isAuthenticated {
                TabView {
                    HomeView()
                        .tabItem { Label("Kezdőlap", systemImage: "house.fill") }
                    CalendarView()
                        .tabItem { Label("Naptár", systemImage: "calendar") }
                    MembersView()
                        .tabItem { Label("Tagok", systemImage: "person.3.fill") }
                    ProfileView()
                        .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                    if store.currentUserRole == .admin {
                        AdminView()
                            .tabItem { Label("Admin", systemImage: "gearshape.fill") }
                    }
                }
            } else {
                LoginView()
            }
        }
        .environmentObject(store)
        .tint(.blue)
    }
}
