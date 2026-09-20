import SwiftUI

struct AdminView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingEditor = false
    @State private var editingEvent: HUNOREvent?

    var body: some View {
        NavigationStack {
            List {
                Section("Áttekintés") {
                    LabeledContent("Tagok", value: "\(store.members.count)")
                    LabeledContent("Események", value: "\(store.events.count)")
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingEvent = nil
                        showingEditor = true
                    } label: {
                        Label("Új esemény", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingEvent) { event in
                EventEditorView(event: event)
            }
            .sheet(isPresented: $showingEditor) {
                EventEditorView(event: nil)
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
