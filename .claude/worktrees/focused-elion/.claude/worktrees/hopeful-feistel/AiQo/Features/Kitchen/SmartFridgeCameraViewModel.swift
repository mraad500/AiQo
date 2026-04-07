@preconcurrency import AVFoundation
internal import Combine
import CoreMedia
import Foundation
import UIKit

final class SmartFridgeCameraViewModel: NSObject, ObservableObject {
    enum PermissionState: Equatable {
        case idle
        case requesting
        case granted
        case denied
        case unavailable
        case failed
    }

    enum ScanPhase: Equatable {
        case previewing
        case capturing
        case processing
        case completed
        case error
    }

    @Published private(set) var permissionState: PermissionState = .idle
    @Published private(set) var scanPhase: ScanPhase = .previewing
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var analyzedItems: [FridgeItem] = []
    @Published private(set) var processingTextKey: String = "kitchen.scanner.processing.biofuel"
    @Published private(set) var errorTextKey: String?
    @Published private(set) var latestResultID: UUID?

    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "aiqo.smartfridge.session")
    private let photoOutput = AVCapturePhotoOutput()
    private lazy var photoCaptureProxy = SmartFridgePhotoCaptureDelegateProxy(owner: self)
    private let processingKeys = [
        "kitchen.scanner.processing.biofuel",
        "kitchen.scanner.processing.extracting",
        "kitchen.scanner.processing.classifying",
        "kitchen.scanner.processing.syncing"
    ]

    private var isSessionConfigured = false
    private var processingTickerTask: Task<Void, Never>?
    private var configuredMaxPhotoDimensions: CMVideoDimensions?

    func startSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .granted
            configureAndStartSessionIfNeeded()
        case .notDetermined:
            permissionState = .requesting
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.permissionState = granted ? .granted : .denied
                    if granted {
                        self.configureAndStartSessionIfNeeded()
                    }
                }
            }
        case .restricted, .denied:
            permissionState = .denied
        @unknown default:
            permissionState = .failed
        }
    }

    func stopSession() {
        processingTickerTask?.cancel()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    func captureAndAnalyze() {
        guard permissionState == .granted else { return }
        guard scanPhase == .previewing else { return }

        errorTextKey = nil
        analyzedItems = []
        scanPhase = .capturing

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .quality
        if let maxDimensions = configuredMaxPhotoDimensions {
            settings.maxPhotoDimensions = maxDimensions
        }

        photoOutput.capturePhoto(with: settings, delegate: photoCaptureProxy)
    }

    func resetScanner() {
        processingTickerTask?.cancel()
        capturedImage = nil
        analyzedItems = []
        errorTextKey = nil
        processingTextKey = processingKeys.first ?? "kitchen.scanner.processing.biofuel"
        scanPhase = .previewing
        configureAndStartSessionIfNeeded()
    }

    func analyzeFridgeImage(image: UIImage) async throws -> [FridgeItem] {
        try await Task.sleep(nanoseconds: 1_700_000_000)

        return [
            FridgeItem(
                name: "kitchen.scanner.item.chicken".localized,
                quantity: 2,
                unit: "kitchen.scanner.unit.pieces".localized,
                alchemyNoteKey: "kitchen.scanner.note.chicken"
            ),
            FridgeItem(
                name: "kitchen.scanner.item.eggs".localized,
                quantity: 6,
                unit: "kitchen.scanner.unit.eggs".localized,
                alchemyNoteKey: "kitchen.scanner.note.eggs"
            ),
            FridgeItem(
                name: "kitchen.scanner.item.broccoli".localized,
                quantity: 1,
                unit: "kitchen.scanner.unit.head".localized,
                alchemyNoteKey: "kitchen.scanner.note.broccoli"
            ),
            FridgeItem(
                name: "kitchen.scanner.item.yogurt".localized,
                quantity: 2,
                unit: "kitchen.scanner.unit.cups".localized,
                alchemyNoteKey: "kitchen.scanner.note.yogurt"
            )
        ]
    }

    private func configureAndStartSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isSessionConfigured {
                guard self.configureSession() else { return }
                self.isSessionConfigured = true
            }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    private func configureSession() -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        defer { captureSession.commitConfiguration() }

        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async {
                self.permissionState = .unavailable
            }
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard captureSession.canAddInput(input) else {
                DispatchQueue.main.async {
                    self.permissionState = .failed
                }
                return false
            }
            captureSession.addInput(input)
        } catch {
            DispatchQueue.main.async {
                self.permissionState = .failed
            }
            return false
        }

        guard captureSession.canAddOutput(photoOutput) else {
            DispatchQueue.main.async {
                self.permissionState = .failed
            }
            return false
        }

        captureSession.addOutput(photoOutput)
        configuredMaxPhotoDimensions = maximumPhotoDimensions(for: camera)
        if let maxDimensions = configuredMaxPhotoDimensions {
            photoOutput.maxPhotoDimensions = maxDimensions
        }

        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        return true
    }

    private func maximumPhotoDimensions(for camera: AVCaptureDevice) -> CMVideoDimensions? {
        var bestDimensions: CMVideoDimensions?
        var bestArea = 0

        for dimensions in camera.activeFormat.supportedMaxPhotoDimensions {
            let area = Int(dimensions.width) * Int(dimensions.height)
            if area > bestArea {
                bestArea = area
                bestDimensions = dimensions
            }
        }

        return bestDimensions
    }

    private func beginProcessingTicker() {
        processingTickerTask?.cancel()
        processingTickerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var index = 0
            while !Task.isCancelled && self.scanPhase == .processing {
                self.processingTextKey = self.processingKeys[index % self.processingKeys.count]
                index += 1
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        DispatchQueue.main.async {
            self.capturedImage = image
            self.scanPhase = .processing
            self.processingTextKey = self.processingKeys.first ?? "kitchen.scanner.processing.biofuel"
            self.beginProcessingTicker()
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }

        Task {
            do {
                let items = try await analyzeFridgeImage(image: image)
                await MainActor.run {
                    self.processingTickerTask?.cancel()
                    self.analyzedItems = items
                    self.scanPhase = .completed
                    self.latestResultID = UUID()
                }
            } catch {
                await MainActor.run {
                    self.processingTickerTask?.cancel()
                    self.errorTextKey = "kitchen.scanner.processing.failed"
                    self.scanPhase = .error
                }
            }
        }
    }

    fileprivate func handleCapturedPhotoOutput(photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            errorTextKey = "kitchen.scanner.processing.failed"
            scanPhase = .error
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            errorTextKey = "kitchen.scanner.processing.failed"
            scanPhase = .error
            return
        }

        handleCapturedPhoto(image)
    }
}

private final class SmartFridgePhotoCaptureDelegateProxy: NSObject, AVCapturePhotoCaptureDelegate {
    weak var owner: SmartFridgeCameraViewModel?

    init(owner: SmartFridgeCameraViewModel) {
        self.owner = owner
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor [weak owner] in
            owner?.handleCapturedPhotoOutput(photo: photo, error: error)
        }
    }
}
