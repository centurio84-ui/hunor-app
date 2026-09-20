import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var currentUser: Member
    @Published var members: [Member]
    @Published var events: [HUNOREvent]

    init() {
        self.members = Member.sampleMembers
        self.currentUser = Member(
            id: UUID(),
            name: "HUNOR tag",
            rank: "Rendfokozat",
            workplace: "Munkahely",
            position: "Beosztás",
            skills: [],
            status: .available
        )
        self.events = HUNOREvent.sampleEvents
    }

    func updateStatus(_ status: AvailabilityStatus) {
        currentUser.status = status
    }

    func addSkill(_ skill: String) {
        let trimmed = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !currentUser.skills.contains(trimmed) else { return }
        currentUser.skills.append(trimmed)
    }

    func removeSkill(_ skill: String) {
        currentUser.skills.removeAll { $0 == skill }
    }
}
