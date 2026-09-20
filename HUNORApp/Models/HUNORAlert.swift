import Foundation

struct HUNORAlert: Identifiable, Hashable {
    let id: UUID
    var title: String
    var message: String
    var priority: String
    var status: String
    var createdAt: Date
    var expiresAt: Date?

    var isActive: Bool {
        status == "active" && (expiresAt == nil || expiresAt! >= .now)
    }

    var priorityLabel: String {
        switch priority {
        case "critical": "KRITIKUS"
        case "high": "MAGAS"
        default: "NORMÁL"
        }
    }
}
