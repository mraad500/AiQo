import AVFoundation
import SwiftUI
import UIKit

struct SmartFridgeCameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> SmartFridgeCameraPreviewView {
        let previewView = SmartFridgeCameraPreviewView()
        previewView.update(session: session)
        return previewView
    }

    func updateUIView(_ uiView: SmartFridgeCameraPreviewView, context: Context) {
        uiView.update(session: session)
    }
}

final class SmartFridgeCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer?.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    func update(session: AVCaptureSession) {
        if previewLayer?.session !== session {
            previewLayer?.session = session
        }
    }
}
