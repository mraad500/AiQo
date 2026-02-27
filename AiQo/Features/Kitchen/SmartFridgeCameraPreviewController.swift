import AVFoundation
import SwiftUI
import UIKit

struct SmartFridgeCameraPreviewControllerRepresentable: UIViewControllerRepresentable {
    let session: AVCaptureSession

    func makeUIViewController(context: Context) -> SmartFridgeCameraPreviewController {
        let controller = SmartFridgeCameraPreviewController()
        controller.update(session: session)
        return controller
    }

    func updateUIViewController(_ uiViewController: SmartFridgeCameraPreviewController, context: Context) {
        uiViewController.update(session: session)
    }
}

final class SmartFridgeCameraPreviewController: UIViewController {
    private let previewView = UIView()
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)
        previewView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(previewView)
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewView.bounds
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    func update(session: AVCaptureSession) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
    }
}
