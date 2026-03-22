import SwiftUI
import SwiftData

struct TribeTabView: View {
    @Binding var userTribe: ArenaTribe?
    @Environment(EmaraArenaViewModel.self) private var arenaVM
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateTribe = false
    @State private var showJoinTribe = false
    @State private var showInviteShare = false
    @State private var showLeaveConfirmation = false
    @State private var isLeaving = false

    var body: some View {
        Group {
            if let tribe = userTribe {
                tribeContent(tribe: tribe)
            } else {
                TribeEmptyState(
                    onCreateTribe: { showCreateTribe = true },
                    onJoinTribe: { showJoinTribe = true }
                )
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            await arenaVM.loadMyTribe(context: modelContext)
            if let tribe = arenaVM.myTribe {
                userTribe = tribe
            }
        }
        .sheet(isPresented: $showCreateTribe) {
            CreateTribeSheet { tribe in userTribe = tribe }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showJoinTribe) {
            JoinTribeSheet { _ in
                userTribe = arenaVM.myTribe
            }
            .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $showInviteShare) {
            if let tribe = userTribe {
                TribeInviteView(tribe: tribe)
            }
        }
        .alert("تبي تطلع من القبيلة؟", isPresented: $showLeaveConfirmation) {
            Button("لا، أبي أبقى", role: .cancel) { }
            Button("أطلع", role: .destructive) {
                isLeaving = true
                Task {
                    let success = await arenaVM.leaveTribe(context: modelContext)
                    if success {
                        userTribe = nil
                    }
                    isLeaving = false
                }
            }
        } message: {
            Text("إذا طلعت، بتفقد مكانك بالقبيلة")
        }
    }

    // MARK: - محتوى القبيلة (عنده قبيلة)

    @ViewBuilder
    private func tribeContent(tribe: ArenaTribe) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero Card
                TribeHeroCard(tribe: tribe)

                // قائمة الأعضاء
                TribeMembersList(
                    tribe: tribe,
                    onInvite: { showInviteShare = true }
                )

                // رمز الدعوة
                TribeInviteCodeCard(tribe: tribe)

                // زر مغادرة القبيلة
                Button {
                    showLeaveConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        if isLeaving {
                            ProgressView()
                                .tint(Color.red.opacity(0.6))
                        }
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14))
                        Text("مغادرة القبيلة")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Color.red.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(isLeaving)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }
}
