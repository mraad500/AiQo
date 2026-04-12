import SwiftUI
struct VibeControlSheet: View {
    @ObservedObject var viewModel: VibeControlViewModel
    @ObservedObject var vibeManager = SpotifyVibeManager.shared
    @ObservedObject var aiqoAudioManager = AiQoAudioManager.shared
    @ObservedObject var vibeAudioEngine = VibeAudioEngine.shared
    @EnvironmentObject private var captainBrain: CaptainViewModel
    @State var isDetailsSheetPresented = false
    @State var showDJChat = false
    @State var showBlendPlaylist = false

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                backgroundArtwork

                topContent

                if viewModel.selectedSource == .aiqoSounds {
                    aiqoSoundsContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    spotifyContent
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                compactControlCard
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.12),
                                Color.black.opacity(0.34)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.spring(), value: viewModel.selectedMode)
        .animation(.spring(), value: viewModel.selectedSource)
        .animation(.spring(), value: vibeManager.isConnected)
        .animation(.spring(), value: vibeManager.playbackState)
        .animation(.spring(), value: aiqoAudioManager.playbackState)
        .onChange(of: viewModel.selectedMode) { _, _ in
            syncAiQoTrackToSelectedModeIfNeeded()
        }
        .alert("vibe.title".localized, isPresented: errorAlertIsPresented) {
            Button("OK", role: .cancel) {
                scheduleActiveAlertClear()
            }
            .accessibilityLabel("حسنًا")
        } message: {
            Text(activeAlertMessage ?? "Something went wrong while starting audio.")
        }
        .sheet(isPresented: $isDetailsSheetPresented) {
            detailsSheet
                .presentationDetents([.fraction(0.46), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showDJChat) {
            DJCaptainChatView()
                .environmentObject(captainBrain)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showBlendPlaylist) {
            HamoudiDJPlaylistView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

#Preview {
    VibeControlSheet(viewModel: VibeControlViewModel())
        .environmentObject(CaptainViewModel())
        .presentationBackground(.ultraThinMaterial)
}
