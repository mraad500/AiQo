import AVFoundation
import SwiftUI
import UIKit

struct QuestPushupChallengeView: View {
    let quest: QuestDefinition
    let onComplete: (_ reps: Int, _ accuracy: Double) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VisionCoachViewModel()
    @State private var didResolveSession = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.05), Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Button {
                        didResolveSession = true
                        viewModel.stop()
                        onCancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(quest.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("\(viewModel.repCount)")
                        .font(.system(size: 88, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text(String(format: L10n.t("gym.pushup.accuracy"), Int(viewModel.accuracyPercent.rounded())))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))

                    Text(viewModel.coachingHint)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    let result = viewModel.currentSessionResult()
                    didResolveSession = true
                    viewModel.stop()
                    onComplete(result.reps, result.accuracy)
                    dismiss()
                } label: {
                    Text(L10n.t("gym.pushup.finish"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 24)

            if viewModel.cameraState == .denied {
                VStack(spacing: 10) {
                    Text(L10n.t("gym.pushup.needCamera"))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Button(L10n.t("gym.quest.openSettings")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .statusBarHidden(true)
        .onAppear { viewModel.start() }
        .onDisappear {
            viewModel.stop()
            if !didResolveSession {
                onCancel()
            }
        }
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
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return layer
    }
}
