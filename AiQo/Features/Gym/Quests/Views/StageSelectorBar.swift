import SwiftUI

struct StageSelectorBar: View {
    let stages: [ChallengeStage]
    @Binding var selectedStageNumber: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(stages) { stage in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedStageNumber = stage.number
                                proxy.scrollTo(stage.id, anchor: .center)
                            }
                        } label: {
                            Text("\(stage.number)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(stage.number == selectedStageNumber ? Color.black : Color.primary)
                                .frame(minWidth: 38)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(stage.number == selectedStageNumber ? GymTheme.beige : Color.white.opacity(0.6), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(stage.number == selectedStageNumber ? Color.white.opacity(0.7) : Color.white.opacity(0.35), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                        .id(stage.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .onAppear {
                proxy.scrollTo(selectedStageNumber, anchor: .center)
            }
            .onChange(of: selectedStageNumber) { newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GymTheme.mint.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.32), lineWidth: 0.5)
                )
        )
    }
}
