import AVFoundation
internal import Combine
import CoreGraphics
import Foundation
import ImageIO
import Vision

final class VisionCoachViewModel: NSObject, ObservableObject {
    enum CameraState: Equatable {
        case idle
        case requestingPermission
        case ready
        case denied
        case unavailable
        case failed
    }

    @Published private(set) var cameraState: CameraState = .idle
    @Published private(set) var repCount: Int = 0
    @Published private(set) var coachingHint: String = L10n.t("quests.vision.hint.initial")

    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "aiqo.visioncoach.session")
    private let visionQueue = DispatchQueue(label: "aiqo.visioncoach.vision")
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let repCounter = PushupRepCounter()

    private var isSessionConfigured = false
    private var usesFrontCamera = true

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartSessionIfNeeded()
        case .notDetermined:
            publishCameraState(.requestingPermission)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndStartSessionIfNeeded()
                } else {
                    self.publishCameraState(.denied)
                }
            }
        case .restricted, .denied:
            publishCameraState(.denied)
        @unknown default:
            publishCameraState(.failed)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
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

            self.publishCameraState(.ready)
        }
    }

    private func configureSession() -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        defer {
            captureSession.commitConfiguration()
        }

        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        guard let camera = preferredCamera() else {
            publishCameraState(.unavailable)
            return false
        }

        usesFrontCamera = camera.position == .front

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard captureSession.canAddInput(input) else {
                publishCameraState(.failed)
                return false
            }
            captureSession.addInput(input)
        } catch {
            publishCameraState(.failed)
            return false
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: visionQueue)

        guard captureSession.canAddOutput(output) else {
            publishCameraState(.failed)
            return false
        }
        captureSession.addOutput(output)

        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }

            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = usesFrontCamera
            }
        }

        repCounter.reset()
        publishRepCount(0)
        publishHint(key: "quests.vision.hint.lower_then_push")
        return true
    }

    private func preferredCamera() -> AVCaptureDevice? {
        if let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            return front
        }

        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func publishCameraState(_ state: CameraState) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraState = state
        }
    }

    private func publishRepCount(_ value: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.repCount = value
        }
    }

    private func publishHint(key: String) {
        DispatchQueue.main.async { [weak self] in
            self?.coachingHint = L10n.t(key)
        }
    }
}

extension VisionCoachViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: visionOrientation,
            options: [:]
        )

        do {
            try handler.perform([poseRequest])
        } catch {
            publishHint(key: "quests.vision.hint.vision_failed")
            return
        }

        guard let observation = poseRequest.results?.first else {
            publishHint(key: "quests.vision.hint.no_body")
            return
        }

        guard let joints = bestArmJoints(from: observation) else {
            publishHint(key: "quests.vision.hint.show_joints")
            return
        }

        let elbowAngle = angleDegrees(a: joints.shoulder, b: joints.elbow, c: joints.wrist)
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let update = repCounter.process(elbowAngle: elbowAngle, timestamp: timestamp)

        if update.repDelta > 0 {
            publishRepCount(repCounter.totalReps)
        }

        publishHint(key: update.hintKey)
    }

    private var visionOrientation: CGImagePropertyOrientation {
        usesFrontCamera ? .leftMirrored : .right
    }

    private func bestArmJoints(from observation: VNHumanBodyPoseObservation) -> ArmJoints? {
        let left = armJoints(
            shoulder: .leftShoulder,
            elbow: .leftElbow,
            wrist: .leftWrist,
            in: observation
        )
        let right = armJoints(
            shoulder: .rightShoulder,
            elbow: .rightElbow,
            wrist: .rightWrist,
            in: observation
        )

        switch (left, right) {
        case let (lhs?, rhs?):
            return lhs.confidence >= rhs.confidence ? lhs : rhs
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private func armJoints(
        shoulder: VNHumanBodyPoseObservation.JointName,
        elbow: VNHumanBodyPoseObservation.JointName,
        wrist: VNHumanBodyPoseObservation.JointName,
        in observation: VNHumanBodyPoseObservation
    ) -> ArmJoints? {
        guard
            let shoulderPoint = try? observation.recognizedPoint(shoulder),
            let elbowPoint = try? observation.recognizedPoint(elbow),
            let wristPoint = try? observation.recognizedPoint(wrist),
            shoulderPoint.confidence > 0.25,
            elbowPoint.confidence > 0.25,
            wristPoint.confidence > 0.25
        else {
            return nil
        }

        let minConfidence = min(shoulderPoint.confidence, elbowPoint.confidence, wristPoint.confidence)
        return ArmJoints(
            shoulder: CGPoint(x: shoulderPoint.x, y: shoulderPoint.y),
            elbow: CGPoint(x: elbowPoint.x, y: elbowPoint.y),
            wrist: CGPoint(x: wristPoint.x, y: wristPoint.y),
            confidence: minConfidence
        )
    }

    private func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> CGFloat {
        let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)

        let dot = (ab.dx * cb.dx) + (ab.dy * cb.dy)
        let magAB = sqrt((ab.dx * ab.dx) + (ab.dy * ab.dy))
        let magCB = sqrt((cb.dx * cb.dx) + (cb.dy * cb.dy))
        let denom = max(magAB * magCB, 0.0001)
        let cosine = max(-1, min(1, dot / denom))

        return CGFloat(acos(cosine) * 180.0 / .pi)
    }
}

private struct ArmJoints {
    let shoulder: CGPoint
    let elbow: CGPoint
    let wrist: CGPoint
    let confidence: Float
}

private struct PushupStateUpdate {
    let repDelta: Int
    let hintKey: String
}

private final class PushupRepCounter {
    private enum Phase {
        case up
        case down
    }

    private var phase: Phase?
    private var smoothedAngles: [CGFloat] = []
    private var lastRepTimestamp: TimeInterval = .leastNormalMagnitude

    private let downThreshold: CGFloat = 95
    private let upThreshold: CGFloat = 155
    private let cooldown: TimeInterval = 0.45

    private(set) var totalReps: Int = 0

    func reset() {
        phase = nil
        smoothedAngles.removeAll()
        lastRepTimestamp = .leastNormalMagnitude
        totalReps = 0
    }

    func process(elbowAngle: CGFloat, timestamp: TimeInterval) -> PushupStateUpdate {
        smoothedAngles.append(elbowAngle)
        if smoothedAngles.count > 6 {
            smoothedAngles.removeFirst()
        }

        let averagedAngle = smoothedAngles.reduce(0, +) / CGFloat(smoothedAngles.count)

        if phase == nil {
            phase = averagedAngle < downThreshold ? .down : .up
            return PushupStateUpdate(repDelta: 0, hintKey: "quests.vision.hint.full_range")
        }

        switch phase {
        case .up:
            if averagedAngle <= downThreshold {
                phase = .down
                return PushupStateUpdate(repDelta: 0, hintKey: "quests.vision.hint.great_depth")
            }
        case .down:
            if averagedAngle >= upThreshold, (timestamp - lastRepTimestamp) >= cooldown {
                phase = .up
                lastRepTimestamp = timestamp
                totalReps += 1
                return PushupStateUpdate(repDelta: 1, hintKey: "quests.vision.hint.rep_counted")
            }
        case nil:
            break
        }

        let hintKey: String = {
            switch phase {
            case .up:
                return "quests.vision.hint.lower_control"
            case .down:
                return "quests.vision.hint.press_up"
            case nil:
                return "quests.vision.hint.keep_visible"
            }
        }()

        return PushupStateUpdate(repDelta: 0, hintKey: hintKey)
    }
}
