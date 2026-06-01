import AVFoundation
import Combine
import QuartzCore

/// Back-camera photoplethysmography (PPG) pulse measurement — for users without an
/// Apple Watch. The user covers the rear camera + flash with a fingertip; each
/// heartbeat changes how much light the finger transmits, so the average RED channel
/// of the frames pulses at the heart rate. We detrend that signal and take the rate
/// of its peaks.
///
/// Runs FULLY on-device — frames are reduced to one red-average number per frame and
/// never stored or transmitted. Camera PPG is inherently approximate, so the window
/// is short and a finger-coverage quality gate guards against garbage readings.
final class CameraPulseMeasurer: NSObject, ObservableObject {
    @Published private(set) var bpm: Int?
    @Published private(set) var progress: Double = 0       // 0…1 across the window
    @Published private(set) var isMeasuring = false
    @Published private(set) var fingerDetected = false
    @Published private(set) var permissionDenied = false

    /// Short by design — camera PPG drifts over longer holds.
    let windowSeconds: Double = 20

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.mraad500.aiqo.kernel.ppg")
    private var device: AVCaptureDevice?
    private var configured = false
    private var samples: [(t: Double, v: Double)] = []      // touched only on `queue`
    private var startTime: CFTimeInterval = 0
    private var lastEstimate: CFTimeInterval = 0
    private var started = false          // the window starts only once a finger is detected
    private var fingerFrames = 0

    // MARK: - Control

    func start() {
        guard !isMeasuring else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginOnQueue()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted { self.beginOnQueue() } else { self.publish { self.permissionDenied = true } }
            }
        default:
            publish { self.permissionDenied = true }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.setTorch(false)
        }
        publish { self.isMeasuring = false }
    }

    private func beginOnQueue() {
        queue.async { [weak self] in
            guard let self else { return }
            self.samples.removeAll()
            self.started = false
            self.fingerFrames = 0
            self.lastEstimate = CACurrentMediaTime()
            guard self.configureIfNeeded() else {
                self.publish { self.permissionDenied = true }
                return
            }
            if !self.session.isRunning { self.session.startRunning() }
            self.setTorch(true)   // AFTER startRunning — the session resets the torch on start
            self.publish {
                self.bpm = nil
                self.progress = 0
                self.fingerDetected = false
                self.permissionDenied = false
                self.isMeasuring = true
            }
        }
    }

    private func configureIfNeeded() -> Bool {
        if configured { return true }
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam) else { return false }
        device = cam
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        guard session.canAddInput(input) else { session.commitConfiguration(); return false }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return false }
        session.addOutput(output)
        session.commitConfiguration()
        configured = true
        return true
    }

    private func setTorch(_ on: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off   // full brightness — reliable; PPG wants strong light
            device.unlockForConfiguration()
        } catch { }
    }

    private func publish(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}

extension CameraPulseMeasurer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let red = averageRed(pb) else { return }
        let now = CACurrentMediaTime()
        let finger = red > 0.5             // finger + flash saturates the red channel high

        // The countdown does NOT run on an empty camera — it starts only once a finger
        // is steadily covering the lens (a real pulse signal is present).
        if !started {
            publish { self.fingerDetected = finger; self.progress = 0 }
            fingerFrames = finger ? fingerFrames + 1 : 0
            if fingerFrames >= 5 {         // ~0.15s of steady coverage → begin the window
                started = true
                startTime = now
                samples.removeAll()
            }
            return
        }

        samples.append((t: now, v: red))
        let elapsed = now - startTime
        var running: Int?
        if elapsed > 5, now - lastEstimate > 0.7 {
            lastEstimate = now
            running = computeBPM(samples)
        }
        let prog = min(1, elapsed / windowSeconds)
        publish {
            self.progress = prog
            self.fingerDetected = finger
            if let running { self.bpm = running }
        }

        if elapsed >= windowSeconds {
            let final = computeBPM(samples)
            publish {
                if let final { self.bpm = final }
                self.progress = 1
            }
            stop()
        }
    }

    /// Mean red (0…1) over a centered ROI, sub-sampled for speed. `nil` on failure.
    private func averageRed(_ pb: CVPixelBuffer) -> Double? {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let x0 = w * 3 / 10, x1 = w * 7 / 10
        let y0 = h * 3 / 10, y1 = h * 7 / 10
        var sum = 0.0, count = 0
        var y = y0
        while y < y1 {
            let row = y * bpr
            var x = x0
            while x < x1 {
                sum += Double(ptr[row + x * 4 + 2])   // BGRA → R at +2
                count += 1
                x += 4
            }
            y += 4
        }
        guard count > 0 else { return nil }
        return sum / Double(count) / 255.0
    }

    /// Detrend + smooth (≈ bandpass) then take the heart-rate period from the
    /// signal's AUTOCORRELATION peak — far more robust to motion/noise than counting
    /// peaks. A confidence gate (normalized autocorrelation ≥ `minConfidence`) means a
    /// noisy or finger-off signal returns NO number rather than a wrong one, so the UI
    /// asks the user to hold steadier instead of showing a bogus reading.
    private func computeBPM(_ s: [(t: Double, v: Double)]) -> Int? {
        guard s.count > 60 else { return nil }
        let times = s.map(\.t), raw = s.map(\.v)
        let span = times.last! - times.first!
        guard span > 5 else { return nil }
        let fs = Double(raw.count - 1) / span               // samples per second

        // Detrend (remove DC + slow drift) then lightly smooth (remove high-freq noise).
        let detrendWin = max(3, Int(fs * 1.0))
        let smoothWin = max(1, Int(fs * 0.08))
        var x = [Double](repeating: 0, count: raw.count)
        for i in raw.indices {
            let lo = max(0, i - detrendWin), hi = min(raw.count - 1, i + detrendWin)
            var m = 0.0
            for j in lo...hi { m += raw[j] }
            x[i] = raw[i] - m / Double(hi - lo + 1)
        }
        if smoothWin > 1 {
            var sm = x
            for i in x.indices {
                let lo = max(0, i - smoothWin), hi = min(x.count - 1, i + smoothWin)
                var m = 0.0
                for j in lo...hi { m += x[j] }
                sm[i] = m / Double(hi - lo + 1)
            }
            x = sm
        }
        let mean = x.reduce(0, +) / Double(x.count)
        for i in x.indices { x[i] -= mean }
        let energy = x.reduce(0) { $0 + $1 * $1 }
        guard energy > 1e-6 else { return nil }

        // Autocorrelation across heart-rate lags (40…180 bpm); pick the strongest.
        let minLag = max(1, Int(fs * 60.0 / 180.0))
        let maxLag = Int(fs * 60.0 / 40.0)
        guard minLag < maxLag, maxLag < x.count - 2 else { return nil }
        var bestLag = -1
        var bestR = 0.0
        for lag in minLag...maxLag {
            var acc = 0.0
            for i in 0..<(x.count - lag) { acc += x[i] * x[i + lag] }
            let r = acc / energy
            if r > bestR { bestR = r; bestLag = lag }
        }
        let minConfidence = 0.5
        guard bestLag > 0, bestR >= minConfidence else { return nil }
        let bpm = Int((60.0 * fs / Double(bestLag)).rounded())
        return (40...180).contains(bpm) ? bpm : nil
    }
}
