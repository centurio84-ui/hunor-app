import SwiftUI

struct AdminView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingEventEditor = false
    @State private var editingEvent: HUNOREvent?
    @State private var editingMember: Member?
    @State private var showingAlertEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section("Áttekintés") {
                    LabeledContent("Tagok", value: "\(store.members.count)")
                    LabeledContent("Események", value: "\(store.events.count)")
                }

                Section("Tagok") {
                    ForEach(store.members.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })) { member in
                        Button {
                            editingMember = member
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(member.name).font(.headline)
                                    Text(member.rank.isEmpty ? member.position : member.rank)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(member.status.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Riasztások") {
                    ForEach(store.alerts.filter { $0.isActive }.prefix(10)) { alert in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(alert.typeLabel).font(.caption.bold())
                                Spacer()
                                Text("\(store.alertResponseCounts[alert.id, default: [:]]["available", default: 0]) elérhető")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(alert.title).font(.headline)
                            Text(alert.message).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Események") {
                    ForEach(store.events.sorted(by: { $0.date < $1.date })) { event in
                        Button {
                            editingEvent = event
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.headline)
                                Text(event.date.formatted(date: .long, time: .shortened))
                                    .foregroundStyle(.secondary)
                                Text("\(event.location) • \(store.eventParticipantCounts[event.id, default: 0]) résztvevő")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteEvent(event.id)
                            } label: {
                                Label("Törlés", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Admin")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAlertEditor = true
                    } label: {
                        Label("Új riasztás", systemImage: "bell.badge.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingEvent = nil
                        showingEventEditor = true
                    } label: {
                        Label("Új esemény", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingEvent) { event in
                EventEditorView(event: event)
            }
            .sheet(isPresented: $showingEventEditor) {
                EventEditorView(event: nil)
            }
            .sheet(item: $editingMember) { member in
                MemberEditorView(member: member, role: store.memberRoles[member.id] ?? .member)
            }
            .sheet(isPresented: $showingAlertEditor) {
                AlertEditorView()
            }
        }
    }
}

private struct MemberEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let member: Member
    let initialRole: MemberRole

    @State private var name: String
    @State private var rank: String
    @State private var workplace: String
    @State private var position: String
    @State private var phone: String
    @State private var role: MemberRole

    init(member: Member, role: MemberRole) {
        self.member = member
        self.initialRole = role
        _name = State(initialValue: member.name)
        _rank = State(initialValue: member.rank)
        _workplace = State(initialValue: member.workplace)
        _position = State(initialValue: member.position)
        _phone = State(initialValue: member.phone)
        _role = State(initialValue: role)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Személyi adatok") {
                    TextField("Név", text: $name)
                    TextField("Rendfokozat", text: $rank)
                    TextField("Munkahely", text: $workplace)
                    TextField("Beosztás", text: $position)
                    TextField("Telefonszám", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Jogosultság") {
                    Picker("Szerepkör", selection: $role) {
                        Text("Tag").tag(MemberRole.member)
                        Text("Admin").tag(MemberRole.admin)
                    }
                }

                Section("Jelenlegi állapot") {
                    LabeledContent("Státusz", value: member.status.rawValue)
                    if !member.skills.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Képességek")
                                .font(.subheadline)
                            Text(member.skills.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Tag szerkesztése")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Mégse") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mentés") {
                        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanName.isEmpty else { return }
                        store.updateMember(member, name: cleanName, rank: rank, workplace: workplace, position: position, phone: phone)
                        store.updateMemberRole(member.id, role: role)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct EventEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let event: HUNOREvent?

    @State private var title: String
    @State private var date: Date
    @State private var location: String
    @State private var details: String

    init(event: HUNOREvent?) {
        self.event = event
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: event?.date ?? .now)
        _location = State(initialValue: event?.location ?? "")
        _details = State(initialValue: event?.details ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Esemény adatai") {
                    TextField("Megnevezés", text: $title)
                    TextField("Helyszín", text: $location)
                    DatePicker("Időpont", selection: $date)
                    TextField("Leírás", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(event == nil ? "Új esemény" : "Esemény szerkesztése")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Mégse") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mentés") {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty else { return }
                        if let event {
                            store.updateEvent(event.id, title: cleanTitle, date: date, location: location, details: details)
                        } else {
                            store.createEvent(title: cleanTitle, date: date, location: location, details: details)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AlertEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var type = "alert"
    @State private var hasExpiry = false
    @State private var expiresAt = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Riasztás") {
                    TextField("Cím", text: $title)
                    TextField("Üzenet", text: $message, axis: .vertical)
                        .lineLimit(4...10)
                    Picker("Típus", selection: $type) {
                        Text("Gyakorlat").tag("exercise")
                        Text("Készenlétbe helyezés").tag("standby")
                        Text("Riasztás").tag("alert")
                    }
                }

                Section("Lejárat") {
                    Toggle("Automatikus lejárat", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Lejárat", selection: $expiresAt, in: .now...)
                    }
                }
            }
            .navigationTitle("Új riasztás")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Mégse") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Küldés") {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty, !cleanMessage.isEmpty else { return }
                        store.createAlert(title: cleanTitle, message: cleanMessage, type: type, expiresAt: hasExpiry ? expiresAt : nil)
                        dismiss()
                    }
                }
            }
        }
    }
}
