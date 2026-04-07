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

    private var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("SmartFridgeCameraPreviewView requires AVCaptureVideoPreviewLayer.")
        }
        return layer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
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
