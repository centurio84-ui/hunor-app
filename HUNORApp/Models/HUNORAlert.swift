import Foundation

struct HUNORAlert: Identifiable, Hashable {
    let id: UUID
    var title: String
    var message: String
    var type: String
    var status: String
    var createdAt: Date
    var expiresAt: Date?

    var isActive: Bool {
        status == "active" && (expiresAt == nil || expiresAt! >= .now)
    }

    var typeLabel: String {
        switch type {
        case "exercise": "GYAKORLAT"
        case "standby": "KÉSZENLÉTBE HELYEZÉS"
        case "alert": "RIASZTÁS"
        default: "RIASZTÁS"
        }
    }
}
