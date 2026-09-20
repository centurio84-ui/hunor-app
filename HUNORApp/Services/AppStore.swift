import Foundation
import SwiftUI
import Supabase

@MainActor
final class AppStore: ObservableObject {
    @Published var currentUser: Member
    @Published var members: [Member] = []
    @Published var events: [HUNOREvent] = []
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        self.currentUser = Member(id: UUID(), name: "", rank: "", workplace: "", position: "", skills: [], status: .available)
        if supabase.auth.currentSession != nil {
            isAuthenticated = true
            Task { await loadData() }
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signIn(email: email, password: password)
            isAuthenticated = true
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            members = []
            events = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadData() async {
        guard let session = supabase.auth.currentSession else { isAuthenticated = false; return }
        isLoading = true
        errorMessage = nil
        do {
            let userID = session.user.id
            let profiles: [ProfileRow] = try await supabase.from("profiles").select().execute().value
            let skills: [SkillRow] = try await supabase.from("skills").select().execute().value
            let availability: [AvailabilityRow] = try await supabase.from("availability").select().execute().value
            let dbEvents: [EventRow] = try await supabase.from("events").select().order("starts_at", ascending: true).execute().value

            members = profiles.map { profile in
                let memberSkills = skills.filter { $0.memberId == profile.id }.map(\.name)
                let latest = availability.filter { $0.memberId == profile.id }.sorted { $0.startDate > $1.startDate }.first
                return Member(id: profile.id, name: profile.name, rank: profile.rank ?? "", workplace: profile.workplace ?? "", position: profile.position ?? "", skills: memberSkills, status: AvailabilityStatus(databaseValue: latest?.status))
            }

            if let own = profiles.first(where: { $0.id == userID }) {
                let ownSkills = skills.filter { $0.memberId == own.id }.map(\.name)
                let latest = availability.filter { $0.memberId == own.id }.sorted { $0.startDate > $1.startDate }.first
                currentUser = Member(id: own.id, name: own.name, rank: own.rank ?? "", workplace: own.workplace ?? "", position: own.position ?? "", skills: ownSkills, status: AvailabilityStatus(databaseValue: latest?.status))
            }

            events = dbEvents.map { HUNOREvent(id: $0.id, title: $0.title, date: $0.startsAt, location: $0.location ?? "", details: $0.description ?? "") }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func updateStatus(_ status: AvailabilityStatus) {
        currentUser.status = status
        Task {
            do {
                try await supabase.from("availability").insert(AvailabilityInsert(memberId: currentUser.id, status: status.databaseValue, startDate: Calendar.current.startOfDay(for: .now), endDate: nil)).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func addSkill(_ skill: String) {
        let trimmed = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !currentUser.skills.contains(trimmed) else { return }
        currentUser.skills.append(trimmed)
        Task {
            do {
                try await supabase.from("skills").insert(SkillInsert(memberId: currentUser.id, name: trimmed)).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func removeSkill(_ skill: String) {
        currentUser.skills.removeAll { $0 == skill }
        Task {
            do {
                try await supabase.from("skills").delete().eq("member_id", value: currentUser.id.uuidString).eq("name", value: skill).execute()
                await loadData()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

private struct ProfileRow: Decodable { let id: UUID; let name: String; let rank: String?; let workplace: String?; let position: String? }
private struct SkillRow: Decodable {
    let id: UUID; let memberId: UUID; let name: String
    enum CodingKeys: String, CodingKey { case id; case memberId = "member_id"; case name }
}
private struct AvailabilityRow: Decodable {
    let id: UUID; let memberId: UUID; let status: String; let startDate: Date; let endDate: Date?
    enum CodingKeys: String, CodingKey { case id; case memberId = "member_id"; case status; case startDate = "start_date"; case endDate = "end_date" }
}
private struct EventRow: Decodable {
    let id: UUID; let title: String; let location: String?; let description: String?; let startsAt: Date; let endsAt: Date?
    enum CodingKeys: String, CodingKey { case id; case title; case location; case description; case startsAt = "starts_at"; case endsAt = "ends_at" }
}
private struct SkillInsert: Encodable {
    let memberId: UUID; let name: String
    enum CodingKeys: String, CodingKey { case memberId = "member_id"; case name }
}
private struct AvailabilityInsert: Encodable {
    let memberId: UUID; let status: String; let startDate: Date; let endDate: Date?
    enum CodingKeys: String, CodingKey { case memberId = "member_id"; case status; case startDate = "start_date"; case endDate = "end_date" }
}
private extension AvailabilityStatus {
    init(databaseValue: String?) {
        switch databaseValue {
        case "vacation": self = .vacation
        case "sick": self = .sick
        case "training": self = .training
        case "unavailable": self = .unavailable
        default: self = .available
        }
    }
    var databaseValue: String {
        switch self {
        case .available: "available"
        case .vacation: "vacation"
        case .sick: "sick"
        case .training: "training"
        case .unavailable: "unavailable"
        }
    }
}
