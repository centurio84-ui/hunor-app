import SwiftUI

struct AlertsView: View {
    @EnvironmentObject private var store: AppStore

    private var visibleAlerts: [HUNORAlert] {
        store.alerts.filter { $0.isActive }
    }

    var body: some View {
        NavigationStack {
            List(visibleAlerts) { alert in
                NavigationLink {
                    AlertDetailView(alert: alert)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(alert.priorityLabel)
                                .font(.caption.bold())
                            Spacer()
                            Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(alert.title)
                            .font(.headline)
                        Text(alert.message)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 5)
                }
            }
            .overlay {
                if visibleAlerts.isEmpty {
                    ContentUnavailableView("Nincs aktív riasztás", systemImage: "bell.slash")
                }
            }
            .navigationTitle("Riasztások")
        }
    }
}

private struct AlertDetailView: View {
    @EnvironmentObject private var store: AppStore
    let alert: HUNORAlert

    var body: some View {
        Form {
            Section("Riasztás") {
                Text(alert.title).font(.headline)
                Text(alert.message)
                LabeledContent("Prioritás", value: alert.priorityLabel)
                LabeledContent("Kiadva", value: alert.createdAt.formatted(date: .long, time: .shortened))
                if let expiresAt = alert.expiresAt {
                    LabeledContent("Lejár", value: expiresAt.formatted(date: .long, time: .shortened))
                }
            }

            Section("Visszajelzés") {
                Button {
                    store.respondToAlert(alert.id, available: true)
                } label: {
                    Label(
                        store.alertResponses[alert.id] == "available" ? "Elérhető vagyok – jelezve" : "Elérhető vagyok",
                        systemImage: "checkmark.circle.fill"
                    )
                }

                Button {
                    store.respondToAlert(alert.id, available: false)
                } label: {
                    Label(
                        store.alertResponses[alert.id] == "unavailable" ? "Nem vagyok elérhető – jelezve" : "Nem vagyok elérhető",
                        systemImage: "xmark.circle"
                    )
                }
            }
        }
        .navigationTitle("Riasztás")
    }
}
