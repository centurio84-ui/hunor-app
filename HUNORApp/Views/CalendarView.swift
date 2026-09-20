import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List(store.events.sorted(by: { $0.date < $1.date })) { event in
                NavigationLink {
                    EventDetailView(event: event)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.title).font(.headline)
                        Text(event.date.formatted(date: .long, time: .shortened))
                            .foregroundStyle(.secondary)
                        Label(event.location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("HUNOR naptár")
        }
    }
}

private struct EventDetailView: View {
    @EnvironmentObject private var store: AppStore
    let event: HUNOREvent

    var body: some View {
        Form {
            Section("Esemény") {
                Text(event.title)
                LabeledContent("Időpont", value: event.date.formatted(date: .long, time: .shortened))
                LabeledContent("Helyszín", value: event.location)
            }
            Section("Leírás") {
                Text(event.details)
            }
            Section("Részvétel") {
                NavigationLink {
                    ParticipantListView(names: store.eventParticipantNames[event.id, default: []])
                } label: {
                    LabeledContent("Résztvevők", value: String(store.eventParticipantCounts[event.id, default: 0]) + " fő")
                }

                Button {
                    store.respondToEvent(event.id, going: true)
                } label: {
                    Label(
                        store.eventResponse(for: event.id) == "going" ? "Részvétel jelezve" : "Részt veszek",
                        systemImage: store.eventResponse(for: event.id) == "going" ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                Button {
                    store.respondToEvent(event.id, going: false)
                } label: {
                    Label(
                        store.eventResponse(for: event.id) == "not_going" ? "Távolmaradás jelezve" : "Nem veszek részt",
                        systemImage: store.eventResponse(for: event.id) == "not_going" ? "xmark.circle.fill" : "xmark.circle"
                    )
                }
            }
        }
        .navigationTitle("Esemény")
    }
}


private struct ParticipantListView: View {
    let names: [String]

    var body: some View {
        List {
            if names.isEmpty {
                ContentUnavailableView("Nincs résztvevő", systemImage: "person.2.slash")
            } else {
                ForEach(names, id: \.self) { name in
                    Label(name, systemImage: "person.fill")
                }
            }
        }
        .navigationTitle("Résztvevők")
    }
}
