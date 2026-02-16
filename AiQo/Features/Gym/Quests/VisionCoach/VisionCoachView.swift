import AVFoundation
import SwiftUI
import UIKit

struct VisionCoachView: View {
    let challenge: Challenge
    @ObservedObject var questsStore: QuestDailyStore

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VisionCoachViewModel()
    @StateObject private var audioFeedback = VisionCoachAudioFeedback()
    @State private var syncedRepCount = 0
    private let connectivity = PhoneConnectivityManager.shared

    var body: some View {
        ZStack {
            if shouldShowCameraFeed {
                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0.10), Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                topBar

                Spacer()

                counterPanel
                progressPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 24)

            cameraStateOverlay
        }
        .statusBarHidden(true)
        .onAppear {
            questsStore.startChallenge(challenge)
            questsStore.refreshOnAppear()
            syncedRepCount = 0
            audioFeedback.resetSession()
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
            audioFeedback.stop()
        }
        .onChange(of: viewModel.repCount) { _, newValue in
            guard newValue > syncedRepCount else { return }

            let detectedRange = (syncedRepCount + 1)...newValue
            let delta = newValue - syncedRepCount
            syncedRepCount = newValue

            for rep in detectedRange {
                audioFeedback.handleRep(rep)
                connectivity.sendVisionCoachEvent(.repDetected)

                if rep == 70 {
                    connectivity.sendVisionCoachEvent(.challengeCompleted)
                }
            }

            guard delta > 0, !questsStore.isCompleted(challenge) else { return }
            questsStore.addPushups(delta, for: challenge)
        }
    }

    private var shouldShowCameraFeed: Bool {
        switch viewModel.cameraState {
        case .idle, .requestingPermission, .ready:
            return true
        case .denied, .unavailable, .failed:
            return false
        }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                Image("Hammoudi5")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )

                Text("Captain Hamoudi")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.35), in: Capsule())

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
        }
    }

    private var counterPanel: some View {
        VStack(spacing: 6) {
            Text("\(viewModel.repCount)")
                .font(.system(size: 94, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text("Detected Push-up Reps")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))

            Text(viewModel.coachingHint)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(challenge.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer(minLength: 10)

                if questsStore.isCompleted(challenge) {
                    Text("Completed")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GymTheme.beige, in: Capsule())
                }
            }

            Text(questsStore.progressText(for: challenge))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            ProgressView(value: questsStore.progressFraction(for: challenge))
                .tint(GymTheme.beige)
                .scaleEffect(y: 1.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.46))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var cameraStateOverlay: some View {
        switch viewModel.cameraState {
        case .idle, .ready:
            EmptyView()
        case .requestingPermission:
            stateCard(
                title: "Requesting Camera Access",
                message: "Allow camera access to start AI Vision Coach.",
                actionTitle: nil,
                action: nil
            )
        case .denied:
            stateCard(
                title: "Camera Access Needed",
                message: "Enable camera permission in Settings to use push-up tracking.",
                actionTitle: "Open Settings",
                action: openSettings
            )
        case .unavailable:
            stateCard(
                title: "Camera Not Available",
                message: "This device does not have a supported camera for Vision Coach.",
                actionTitle: nil,
                action: nil
            )
        case .failed:
            stateCard(
                title: "Camera Setup Failed",
                message: "Please close this screen and try again.",
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func stateCard(
        title: String,
        message: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(GymTheme.beige, in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }

        return previewLayer
    }
}
