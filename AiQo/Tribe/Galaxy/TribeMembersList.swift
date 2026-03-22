import SwiftUI

struct TribeMembersList: View {
    let tribe: ArenaTribe
    var onInvite: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // العنوان
            Text("الأعضاء")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(TribePalette.textPrimary)

            LazyVStack(spacing: 8) {
                ForEach(Array(tribe.members.enumerated()), id: \.element.id) { index, member in
                    let isCurrentUser = member.userID == SupabaseService.shared.currentUserID
                    let resolvedUsername: String = {
                        if isCurrentUser {
                            return UserProfileStore.shared.current.username ?? "aiqo.me"
                        }
                        // displayName is already resolved from profiles by syncTribeWithProfileMembers
                        return member.displayName.lowercased().replacingOccurrences(of: " ", with: ".")
                    }()

                    TribeMemberRow(
                        member: member,
                        memberIndex: index,
                        points: isCurrentUser ? max(UserDefaults.standard.integer(forKey: LevelStorageKeys.legacyTotalPoints), 0) : 0,
                        level: isCurrentUser ? max(UserDefaults.standard.integer(forKey: LevelStorageKeys.currentLevel), 1) : 1,
                        username: resolvedUsername
                    )
                }

                // زر دعوة عضو جديد
                if !tribe.isFull {
                    Button(action: onInvite) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(.subheadline, design: .rounded))
                                .symbolRenderingMode(.hierarchical)
                            Text("ادعُ عضو جديد (متبقي \(5 - tribe.members.count))")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "2D6B4A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 4])
                                )
                                .foregroundStyle(Color(hex: "2D6B4A").opacity(0.3))
                        )
                    }
                }
            }
        }
    }
}
