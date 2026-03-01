import SwiftUI

struct TribeRankingScreen: View {
    @StateObject private var tribeStore = TribeStore.shared
    @StateObject private var entitlementStore = EntitlementStore.shared
    @StateObject private var userProfileStore = UserProfileStore.shared

    @State private var inviteCode: String = ""
    @State private var isCreateSheetPresented = false
    @State private var isPaywallPresented = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let tribe = tribeStore.currentTribe {
                        joinedTribeContent(tribe: tribe)
                    } else {
                        emptyTribeContent
                    }

                    if let error = tribeStore.error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isCreateSheetPresented) {
                CreateTribeSheet { name in
                    tribeStore.createTribe(name: name)
                }
            }
            .sheet(isPresented: $isPaywallPresented) {
                PaywallView(dismissOnFamilyUnlock: true)
            }
            .onAppear {
                tribeStore.fetchTribe()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tribe")
                .tribeTitle()
                .foregroundStyle(.black)

            Text("The tribe only shows level and shared energy contribution. No health details are shown.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyTribeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.tribeMint)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            entitlementStore.canCreateTribe ? "Create a new tribe" : "Create a tribe (locked)",
                            systemImage: entitlementStore.canCreateTribe ? "person.3.sequence.fill" : "lock.fill"
                        )
                        .tribeBody(size: 18)

                        Text("Tribe creation is only available on the family plan. If you're not eligible, the paywall will open.")
                            .font(.footnote)
                            .foregroundStyle(.black.opacity(0.72))

                        Text(entitlementStore.canCreateTribe ? "You can create a tribe now." : "Family plan required to create a tribe.")
                            .font(.footnote)
                            .foregroundStyle(.black.opacity(0.72))

                        Button {
                            if entitlementStore.canCreateTribe {
                                isCreateSheetPresented = true
                            } else {
                                isPaywallPresented = true
                            }
                        } label: {
                            Text(entitlementStore.canCreateTribe ? "Create Tribe" : "Open Family Premium")
                                .tribeBody(size: 17)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.tribeOrange)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(18)
                }
                .frame(height: 184)

            VStack(alignment: .leading, spacing: 12) {
                Text("Join with code")
                    .tribeBody(size: 19)

                TextField("Enter invite code", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    tribeStore.joinTribe(inviteCode: inviteCode)
                    if tribeStore.currentTribe != nil {
                        inviteCode = ""
                    }
                } label: {
                    Text("Join now")
                        .tribeBody(size: 17)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            if tribeStore.loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func joinedTribeContent(tribe: Tribe) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            tribeSummaryCard(tribe: tribe)
            privacyControls
            missionsSection
            membersSection
        }
    }

    private func tribeSummaryCard(tribe: Tribe) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.tribeMint)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tribe.name)
                        .tribeTitle(size: 26)

                    Text("Invite code: \(tribe.inviteCode)")
                        .tribeBody(size: 17)

                    Text("Created: \(formatter.string(from: tribe.createdAt))")
                        .font(.footnote)
                        .foregroundStyle(.black.opacity(0.72))

                    Button(role: .destructive) {
                        tribeStore.leaveTribe()
                    } label: {
                        Text("Leave tribe")
                            .tribeBody(size: 16)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.88))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(18)
            }
            .frame(height: 205)
    }

    private var privacyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your tribe profile privacy")
                .tribeBody(size: 19)

            Picker(
                "Your tribe profile privacy",
                selection: Binding(
                    get: { userProfileStore.tribePrivacyMode },
                    set: { userProfileStore.setTribePrivacyMode($0) }
                )
            ) {
                Text("Private").tag(PrivacyMode.private)
                Text("Public").tag(PrivacyMode.public)
            }
            .pickerStyle(.segmented)

            Text("Private mode hides your name and real avatar, and only keeps level and shared energy visible.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tribe missions")
                .tribeBody(size: 19)

            if tribeStore.loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if tribeStore.missions.isEmpty {
                Text("No missions right now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tribeStore.missions) { mission in
                    TribeMissionCard(mission: mission)
                }
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tribe members")
                .tribeBody(size: 19)

            if tribeStore.members.isEmpty {
                Text("No members yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tribeStore.members) { member in
                    TribeMemberCard(member: member)
                }
            }
        }
    }
}

private struct TribeMemberCard: View {
    let member: TribeMember

    var body: some View {
        HStack(spacing: 12) {
            TribeMemberAvatar(member: member)

            if member.privacyMode == .public {
                Text(member.displayName)
                    .tribeBody(size: 17)
                    .foregroundStyle(.black)
                    .lineLimit(1)
            }

            Spacer()

            EnergyBadge(value: member.energyContributionToday)
            CompactLevelBadge(level: member.level)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TribeMemberAvatar: View {
    let member: TribeMember

    var body: some View {
        Circle()
            .fill(Color.tribeAvatar)
            .frame(width: 48, height: 48)
            .overlay {
                if member.privacyMode == .private {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if member.avatarURL == "local-avatar", let image = UserProfileStore.shared.loadAvatar() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else if let avatarURL = member.avatarURL, !avatarURL.isEmpty, !avatarURL.hasPrefix("http") {
                    Image(avatarURL)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else if let avatarURL = member.avatarURL, avatarURL.hasPrefix("http"), let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(Circle())
                } else {
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .tribeBody(size: 18)
                        .foregroundStyle(.black)
                }
            }
    }
}

private struct EnergyBadge: View {
    let value: Int

    var body: some View {
        Capsule()
            .fill(Color.tribeOrange.opacity(0.9))
            .overlay {
                Text("Energy \(value)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
            }
            .frame(height: 34)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct CompactLevelBadge: View {
    let level: Int

    var body: some View {
        Capsule()
            .fill(Color.tribeLevel)
            .overlay {
                Text("Lv \(level)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
            }
            .frame(height: 34)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct TribeMissionCard: View {
    let mission: TribeMission

    private var progress: Double {
        guard mission.targetValue > 0 else { return 0 }
        return min(Double(mission.progressValue) / Double(mission.targetValue), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mission.title)
                    .tribeBody(size: 16)

                Spacer()

                Text("\(mission.progressValue)/\(mission.targetValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(.black)

            Text("Ends: \(mission.endsAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CreateTribeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tribeName: String = ""

    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Tribe name") {
                    TextField("Example: Wolves", text: $tribeName)
                }

                Section {
                    Text("Only family plan members can create a tribe. Local demo data will be used until Supabase tribe tables are connected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Tribe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(tribeName)
                        dismiss()
                    }
                    .disabled(tribeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

extension View {
    func tribeTitle(size: CGFloat = 34) -> some View {
        font(.system(size: size, weight: .semibold, design: .rounded))
    }

    func tribeBody(size: CGFloat = 18) -> some View {
        font(.system(size: size, weight: .semibold, design: .rounded))
    }
}

extension Color {
    static let tribeOrange = Color(red: 0.97, green: 0.81, blue: 0.60)
    static let tribeMint = Color(red: 0.79, green: 0.95, blue: 0.87)
    static let tribeLevel = Color(red: 0.98, green: 0.84, blue: 0.63)
    static let tribeAvatar = Color(red: 0.94, green: 0.94, blue: 0.94)
}
