import SwiftUI

struct MembersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""

    private var filteredMembers: [Member] {
        guard !searchText.isEmpty else { return store.members }
        return store.members.filter { member in
            member.name.localizedCaseInsensitiveContains(searchText) ||
            member.skills.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredMembers) { member in
                NavigationLink {
                    MemberDetailView(member: member)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name).font(.headline)
                        Text(member.rank)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(member.status.rawValue)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $searchText, prompt: "Név vagy képesség")
            .navigationTitle("Tagok")
        }
    }
}

private struct MemberDetailView: View {
    let member: Member

    private var phoneURL: URL? {
        let cleaned = member.phone.filter { $0.isNumber || $0 == "+" }
        return cleaned.isEmpty ? nil : URL(string: "tel:\(cleaned)")
    }

    var body: some View {
        List {
            Section("Adatok") {
                LabeledContent("Rendfokozat", value: member.rank)
                LabeledContent("Munkahely", value: member.workplace)
                LabeledContent("Beosztás", value: member.position)
                LabeledContent("Státusz", value: member.status.rawValue)

                if let phoneURL {
                    Link(destination: phoneURL) {
                        Label(member.phone, systemImage: "phone.fill")
                    }
                }
            }

            Section("Képességek") {
                ForEach(member.skills, id: \.self) { skill in
                    Text(skill)
                }
            }
        }
        .navigationTitle(member.name)
    }
}
