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
            Section {
                Button("Részt veszek") {}
            }
        }
        .navigationTitle("Esemény")
    }
}
