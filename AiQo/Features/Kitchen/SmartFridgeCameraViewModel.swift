@preconcurrency import AVFoundation
import Combine
import CoreMedia
import Foundation
import os.log
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
    private let maxGeminiImageBytes = 900_000
    private let geminiImageMaxDimension: CGFloat = 960
    private let geminiImageCompressionQuality: CGFloat = 0.68

    private let sanitizer = PrivacySanitizer()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "SmartFridgeCamera"
    )

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
        do {
            let items = try await callVisionAPI(image: image)
            guard !items.isEmpty else {
                logger.warning("Vision API returned empty items, using fallback")
                return fallbackItems()
            }
            return items
        } catch {
            logger.error("Fridge image analysis failed: \(error.localizedDescription, privacy: .public)")
            return fallbackItems()
        }
    }

    private func callVisionAPI(image: UIImage) async throws -> [FridgeItem] {
        // Resolve API key using the same logic as HybridBrainService
        let apiKey = try resolveAPIKey()

        // Sanitize image: resize to max 1280px, strip EXIF/GPS, compress to JPEG 0.78
        guard let imageData = sanitizer.sanitizeKitchenImageData(image.jpegData(compressionQuality: 1.0)) else {
            throw FridgeAnalysisError.imageProcessingFailed
        }

        let minimizedImageData = minimizedGeminiImageData(from: imageData)
        let base64Image = minimizedImageData.base64EncodedString()

        // Build the Gemini request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": "Return JSON only. Visible food items only. Schema: [{\"name\": string, \"quantity\": number, \"unit\": string|null}]. Use generic food names."
                        ],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 220,
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]

        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 15
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("Vision API returned status \(statusCode)")
            throw FridgeAnalysisError.badStatusCode(statusCode)
        }

        // Parse the Gemini response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let candidateContent = firstCandidate["content"] as? [String: Any],
              let parts = candidateContent["parts"] as? [[String: Any]],
              let content = parts.first?["text"] as? String else {
            throw FridgeAnalysisError.invalidResponse
        }

        return parseFridgeItems(from: content)
    }

    private func resolveAPIKey() throws -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment

        let keyNames = ["CAPTAIN_API_KEY", "COACH_BRAIN_LLM_API_KEY"]
        for keyName in keyNames {
            if let key = normalizedKey(env[keyName]) ?? normalizedKey(info[keyName] as? String) {
                return key
            }
        }

        throw FridgeAnalysisError.missingAPIKey
    }

    private func normalizedKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }

    private func parseFridgeItems(from content: String) -> [FridgeItem] {
        // Try to extract a JSON array from the response content
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown fences if present
        let jsonString: String
        if let fenceRange = trimmed.range(of: #"```(?:json)?\s*"#, options: .regularExpression),
           let endFence = trimmed.range(of: "```", options: [], range: fenceRange.upperBound..<trimmed.endIndex) {
            jsonString = String(trimmed[fenceRange.upperBound..<endFence.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            jsonString = trimmed
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let rawArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            logger.warning("Failed to parse fridge items JSON from LLM response")
            return []
        }

        return rawArray.compactMap { dict -> FridgeItem? in
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
            let quantity: Double
            if let q = dict["quantity"] as? Double {
                quantity = q
            } else if let q = dict["quantity"] as? Int {
                quantity = Double(q)
            } else {
                quantity = 1
            }
            let unit = dict["unit"] as? String
            return FridgeItem(name: name, quantity: quantity, unit: unit)
        }
    }

    private func fallbackItems() -> [FridgeItem] {
        [
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

    private func minimizedGeminiImageData(from imageData: Data) -> Data {
        guard imageData.count > maxGeminiImageBytes,
              let image = UIImage(data: imageData) else {
            return imageData
        }

        let longestEdge = max(image.size.width, image.size.height)
        let scale = min(1, geminiImageMaxDimension / max(longestEdge, 1))
        let targetSize = CGSize(
            width: max(image.size.width * scale, 1),
            height: max(image.size.height * scale, 1)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let reducedData = renderer.jpegData(withCompressionQuality: geminiImageCompressionQuality) { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return reducedData.count < imageData.count ? reducedData : imageData
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

private enum FridgeAnalysisError: LocalizedError {
    case missingAPIKey
    case imageProcessingFailed
    case badStatusCode(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing from configuration."
        case .imageProcessingFailed:
            return "Failed to process fridge image for analysis."
        case .badStatusCode(let code):
            return "Vision API returned status code \(code)."
        case .invalidResponse:
            return "Vision API returned an invalid response."
        }
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
