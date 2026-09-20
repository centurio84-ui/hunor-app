import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var newSkill = ""
    @State private var showingStatus = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Saját adatok") {
                    LabeledContent("Név", value: store.currentUser.name)
                    LabeledContent("Rendfokozat", value: store.currentUser.rank)
                    LabeledContent("Munkahely", value: store.currentUser.workplace)
                    LabeledContent("Beosztás", value: store.currentUser.position)
                    if !store.currentUser.phone.isEmpty {
                        LabeledContent("Telefon", value: store.currentUser.phone)
                    }
                }

                Section("Elérhetőség") {
                    Button {
                        showingStatus = true
                    } label: {
                        HStack {
                            Text("Státusz")
                            Spacer()
                            Text(store.currentUser.status.rawValue)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Section("Képességeim") {
                    ForEach(store.currentUser.skills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Button(role: .destructive) {
                                store.removeSkill(skill)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    HStack {
                        TextField("Új képesség", text: $newSkill)
                        Button("Hozzáad") {
                            store.addSkill(newSkill)
                            newSkill = ""
                        }
                        .disabled(newSkill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await store.signOut() }
                    } label: {
                        Text("Kijelentkezés")
                    }
                }
            }
            .navigationTitle("Profil")
            .confirmationDialog("Elérhetőségi státusz", isPresented: $showingStatus) {
                ForEach(AvailabilityStatus.allCases) { status in
                    Button(status.rawValue) {
                        store.updateStatus(status)
                    }
                }
            }
        }
    }
}
