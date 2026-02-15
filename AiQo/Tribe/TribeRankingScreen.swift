import SwiftUI
import UIKit

// MARK: - Data Model
struct TribeListMember: Identifiable, Hashable {
    let id: UUID
    var name: String
    var level: Int
    var flag: String?
    var hasAvatar: Bool
    var avatarName: String?

    static func stableID(for name: String) -> UUID {
        let data = Array(name.utf8)
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, b) in data.enumerated() { bytes[i % 16] = bytes[i % 16] &+ b }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

enum TribeSegment: String, CaseIterable, Identifiable {
    case global = "Global"
    case region = "Region"
    case friends = "Friends"

    var id: String { rawValue }
    var index: Int { TribeSegment.allCases.firstIndex(of: self) ?? 0 }

    var title: String {
        switch self {
        case .global: return NSLocalizedString("tribe.segment.global", value: "Global", comment: "")
        case .region: return NSLocalizedString("tribe.segment.region", value: "Arena", comment: "")
        case .friends: return NSLocalizedString("tribe.segment.friends", value: "Friends", comment: "")
        }
    }
}

// MARK: - Screen
struct TribeRankingScreen: View {
    @State private var selectedSegment: TribeSegment = .global
    @State private var members: [TribeListMember] = []
    @State private var friends: [TribeListMember] = []
    @State private var selectedMember: TribeListMember?
    @State private var challenges: [String] = [
        NSLocalizedString("tribe.challenge.10k", value: "10K Steps", comment: ""),
        NSLocalizedString("tribe.challenge.no_sugar", value: "No Sugar Today", comment: ""),
        NSLocalizedString("tribe.challenge.calm", value: "5 Min Calm", comment: "")
    ]
    @State private var newChallenge: String = ""

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 20) {
                Text(NSLocalizedString("tribe.title", value: "Tribe", comment: ""))
                    .tribeTitle()
                    .foregroundStyle(.black)
                    .padding(.top, -55)

                Picker("", selection: $selectedSegment) {
                    ForEach(TribeSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .tint(Color.tribeOrange)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.top, -12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        switch selectedSegment {
                        case .global:
                            ForEach(members) { member in
                                TribePillRow(member: member)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedMember = member }
                            }
                        case .region:
                            RegionInlineChallenges(
                                challenges: $challenges,
                                newChallenge: $newChallenge
                            )
                        case .friends:
                            ForEach(friends) { member in
                                TribePillRow(member: member)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedMember = member }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear { if members.isEmpty { seedDemo() } }
        .sheet(item: $selectedMember) { member in
            TribeProfileSheet(member: member)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }

    private func seedDemo() {
        members = [
            TribeListMember(id: TribeListMember.stableID(for: "Hamoodi"), name: "Hamoodi", level: 17, flag: "🇮🇶", hasAvatar: true, avatarName: "Hammoudi5"),
            TribeListMember(id: TribeListMember.stableID(for: "Mustafa"), name: "Mustafa", level: 15, flag: nil, hasAvatar: true, avatarName: "TribeAvatar1"),
            TribeListMember(id: TribeListMember.stableID(for: "Ali"), name: "Ali", level: 10, flag: nil, hasAvatar: true, avatarName: "TribeAvatar2"),
            TribeListMember(id: TribeListMember.stableID(for: "Ahmed"), name: "Ahmed", level: 8, flag: nil, hasAvatar: true, avatarName: "TribeAvatar3"),
            TribeListMember(id: TribeListMember.stableID(for: "noor"), name: "noor", level: 6, flag: nil, hasAvatar: true, avatarName: "TribeAvatar4"),
            TribeListMember(id: TribeListMember.stableID(for: "Sultan"), name: "Sultan", level: 5, flag: nil, hasAvatar: true, avatarName: "TribeAvatar5")
        ]

        friends = [
            TribeListMember(id: TribeListMember.stableID(for: "Sara"), name: "Sara", level: 14, flag: "🇸🇦", hasAvatar: true, avatarName: "TribeAvatar1"),
            TribeListMember(id: TribeListMember.stableID(for: "Zain"), name: "Zain", level: 12, flag: "🇮🇶", hasAvatar: true, avatarName: "TribeAvatar2"),
            TribeListMember(id: TribeListMember.stableID(for: "Maya"), name: "Maya", level: 11, flag: "🇦🇪", hasAvatar: true, avatarName: "TribeAvatar3"),
            TribeListMember(id: TribeListMember.stableID(for: "Omar"), name: "Omar", level: 9, flag: "🇯🇴", hasAvatar: true, avatarName: "TribeAvatar4"),
            TribeListMember(id: TribeListMember.stableID(for: "Lena"), name: "Lena", level: 7, flag: "🇱🇧", hasAvatar: true, avatarName: "TribeAvatar5")
        ]
    }
}

// MARK: - Components

struct TribePillRow: View {
    let member: TribeListMember

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.tribeAvatar)
                .overlay {
                    if member.hasAvatar, let avatar = member.avatarName, let uiImage = UIImage(named: avatar) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else if member.hasAvatar {
                        Text(String(member.name.prefix(1)).uppercased())
                            .tribeBody(size: 18)
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 52, height: 52)

            ZStack {
                Capsule()
                    .fill(Color.tribeMint)

                HStack(spacing: 10) {
                    Text(member.name)
                        .tribeBody(size: 20)
                        .foregroundStyle(.black)

                    if let flag = member.flag {
                        Text(flag)
                            .font(.system(size: 18))
                    }

                    Spacer()

                    TribeLevelPill(level: member.level)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 56)
        }
    }
}

struct TribeLevelPill: View {
    let level: Int

    var body: some View {
        Capsule()
            .fill(Color.tribeLevel)
            .frame(width: 110, height: 40)
            .overlay(
                Text(String(format: NSLocalizedString("tribe.level.format", value: "Level %d", comment: ""), level))
                    .tribeBody(size: 18)
                    .foregroundStyle(.black)
            )
    }
}

// MARK: - Profile Sheet
struct TribeProfileSheet: View {
    let member: TribeListMember

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 44, height: 6)
                .padding(.top, 8)

            Circle()
                .fill(Color.tribeAvatar)
                .frame(width: 90, height: 90)
                .overlay(
                    Text(String(member.name.prefix(1)).uppercased())
                        .tribeBody(size: 30)
                        .foregroundStyle(.black)
                )

            VStack(spacing: 6) {
                Text(member.name)
                    .tribeTitle(size: 26)
                Text(String(format: NSLocalizedString("tribe.level.format", value: "Level %d", comment: ""), member.level))
                    .tribeBody(size: 18)
                    .foregroundStyle(.secondary)
            }

            if let flag = member.flag {
                Text(flag)
                    .font(.system(size: 28))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Region Challenges
struct RegionInlineChallenges: View {
    @Binding var challenges: [String]
    @Binding var newChallenge: String

    var body: some View {
        VStack(spacing: 18) {
            Text(NSLocalizedString("tribe.region.title", value: "Region Challenges", comment: ""))
                .tribeTitle(size: 28)

            VStack(spacing: 12) {
                ForEach(challenges, id: \.self) { item in
                    Capsule()
                        .fill(Color.tribeMint)
                        .frame(height: 50)
                        .overlay(
                            HStack {
                                Text(item)
                                    .tribeBody(size: 18)
                                    .foregroundStyle(.black)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        )
                }
            }
            .padding(.top, 6)

            VStack(spacing: 10) {
                TextField(NSLocalizedString("tribe.challenge.add_placeholder", value: "Add a challenge", comment: ""), text: $newChallenge)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16, weight: .bold))

                Button {
                    let trimmed = newChallenge.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    challenges.insert(trimmed, at: 0)
                    newChallenge = ""
                } label: {
                    Text(NSLocalizedString("tribe.challenge.add_action", value: "Add Challenge", comment: ""))
                        .tribeBody(size: 17)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.tribeOrange)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Fonts
extension View {
    func tribeTitle(size: CGFloat = 34) -> some View {
        self.font(.system(size: size, weight: .semibold, design: .rounded))
    }

    func tribeBody(size: CGFloat = 18) -> some View {
        self.font(.system(size: size, weight: .semibold, design: .rounded))
    }
}

// MARK: - Colors
extension Color {
    static let tribeOrange = Color(red: 0.97, green: 0.81, blue: 0.60)
    static let tribeMint = Color(red: 0.79, green: 0.95, blue: 0.87)
    static let tribeLevel = Color(red: 0.98, green: 0.84, blue: 0.63)
    static let tribeAvatar = Color(red: 0.94, green: 0.94, blue: 0.94)
}
