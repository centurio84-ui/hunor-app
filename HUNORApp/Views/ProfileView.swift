import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var newSkill = ""
    @State private var showingStatus = false
    @State private var selectedStatus: AvailabilityStatus = .available
    @State private var statusStartDate = Calendar.current.startOfDay(for: .now)
    @State private var statusEndDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now

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
                        selectedStatus = store.currentUser.status
                        statusStartDate = Calendar.current.startOfDay(for: .now)
                        statusEndDate = Calendar.current.date(byAdding: .day, value: 1, to: statusStartDate) ?? statusStartDate
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
            .sheet(isPresented: $showingStatus) {
                NavigationStack {
                    Form {
                        Section("Státusz") {
                            Picker("Státusz", selection: $selectedStatus) {
                                ForEach(AvailabilityStatus.allCases) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                        }

                        if selectedStatus == .vacation || selectedStatus == .training {
                            Section("Időszak") {
                                DatePicker("Kezdete", selection: $statusStartDate, displayedComponents: .date)
                                DatePicker("Vége", selection: $statusEndDate, in: statusStartDate..., displayedComponents: .date)
                            }
                        }

                        Section {
                            Button("Mentés") {
                                let datedStatus = selectedStatus == .vacation || selectedStatus == .training
                                store.updateStatus(selectedStatus, startDate: statusStartDate, endDate: datedStatus ? statusEndDate : nil)
                                showingStatus = false
                            }
                        }
                    }
                    .navigationTitle("Elérhetőség")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Mégse") { showingStatus = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}
