import AVFoundation
import SwiftUI
import UIKit

struct QuestCameraPermissionGateView: View {
    let onAuthorized: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var requesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.t("gym.camera.privacy"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))

            Text(L10n.t("gym.camera.description"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            statusBlock

            actionButton
        }
        .padding(20)
        .onAppear {
            status = AVCaptureDevice.authorizationStatus(for: .video)
            continueIfAuthorized()
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch status {
        case .authorized:
            Label(L10n.t("gym.camera.granted"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
        case .notDetermined:
            Label(L10n.t("gym.camera.needPermission"), systemImage: "camera.fill")
                .foregroundStyle(Color.blue)
        case .denied, .restricted:
            Label(L10n.t("gym.camera.denied"), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
        @unknown default:
            Label(L10n.t("gym.camera.unknown"), systemImage: "questionmark.circle")
                .foregroundStyle(Color.gray)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .authorized:
            Button(L10n.t("gym.camera.startChallenge")) {
                onAuthorized()
                dismiss()
            }
            .buttonStyle(.borderedProminent)

        case .notDetermined:
            Button(requesting ? L10n.t("gym.camera.requesting") : L10n.t("gym.camera.allowCamera")) {
                requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .disabled(requesting)

        case .denied, .restricted:
            Button(L10n.t("gym.quest.openSettings")) {
                openSettings()
            }
            .buttonStyle(.bordered)

        @unknown default:
            EmptyView()
        }
    }

    private func requestPermission() {
        requesting = true
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                requesting = false
                status = AVCaptureDevice.authorizationStatus(for: .video)
                if granted {
                    onAuthorized()
                    dismiss()
                }
            }
        }
    }

    private func continueIfAuthorized() {
        guard status == .authorized else { return }
        DispatchQueue.main.async {
            onAuthorized()
            dismiss()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
