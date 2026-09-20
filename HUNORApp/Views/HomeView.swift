import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("HUNOR")
                        .font(.largeTitle.bold())

                    Text("Jó napot!")
                        .foregroundStyle(.secondary)

                    StatusCard(status: store.currentUser.status)

                    if let nextEvent = store.events.sorted(by: { $0.date < $1.date }).first {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Következő esemény")
                                .font(.headline)
                            Text(nextEvent.title)
                                .font(.title3.bold())
                            Label(nextEvent.location, systemImage: "mappin.and.ellipse")
                            Text(nextEvent.date.formatted(date: .long, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mai állomány")
                            .font(.headline)
                        HStack {
                            MetricView(title: "Elérhető", value: "124", symbol: "checkmark.circle.fill")
                            MetricView(title: "Szabadság", value: "18", symbol: "sun.max.fill")
                            MetricView(title: "Képzés", value: "8", symbol: "graduationcap.fill")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Kezdőlap")
        }
    }
}

private struct StatusCard: View {
    let status: AvailabilityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Jelenlegi státusz")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(status.rawValue)
                .font(.title2.bold())
            Text("A státuszodat a Profil menüpontban módosíthatod.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct MetricView: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
            Text(value).font(.title3.bold())
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
