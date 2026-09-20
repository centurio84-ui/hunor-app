import Foundation

struct HUNOREvent: Identifiable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var location: String
    var details: String

    static let sampleEvents: [HUNOREvent] = [
        HUNOREvent(
            id: UUID(),
            title: "HUNOR rendszerbeállító gyakorlat",
            date: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
            location: "Hajdúszoboszló",
            details: "Közös HUNOR gyakorlat és képességfenntartás."
        ),
        HUNOREvent(
            id: UUID(),
            title: "HUNOR vezetői értekezlet",
            date: Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now,
            location: "Budapest",
            details: "Vezetői egyeztetés."
        )
    ]
}
