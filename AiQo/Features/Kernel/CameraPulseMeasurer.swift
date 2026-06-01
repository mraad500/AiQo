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
    let windowSeconds: Double = 12

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.mraad500.aiqo.kernel.ppg")
    private var device: AVCaptureDevice?
    private var configured = false
    private var samples: [(t: Double, v: Double)] = []      // touched only on `queue`
    private var startTime: CFTimeInterval = 0
    private var lastEstimate: CFTimeInterval = 0

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
            self.startTime = CACurrentMediaTime()
            self.lastEstimate = self.startTime
            guard self.configureIfNeeded() else {
                self.publish { self.permissionDenied = true }
                return
            }
            self.setTorch(true)
            if !self.session.isRunning { self.session.startRunning() }
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
            if on { try? device.setTorchModeOn(level: 0.6) } else { device.torchMode = .off }
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
        samples.append((t: now, v: red))

        let elapsed = now - startTime
        let finger = red > 0.45            // finger + flash saturates the red channel high
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

    /// Detrend (subtract a moving average) → peak-detect → BPM from the median
    /// inter-peak interval. Returns nil when the signal is too weak/short.
    private func computeBPM(_ s: [(t: Double, v: Double)]) -> Int? {
        guard s.count > 40 else { return nil }
        let times = s.map(\.t), values = s.map(\.v)
        let span = times.last! - times.first!
        guard span > 4 else { return nil }
        let dt = span / Double(times.count - 1)
        let maWin = max(3, Int(0.75 / dt))

        var ac = [Double](repeating: 0, count: values.count)
        for i in values.indices {
            let lo = max(0, i - maWin), hi = min(values.count - 1, i + maWin)
            var m = 0.0
            for j in lo...hi { m += values[j] }
            ac[i] = values[i] - m / Double(hi - lo + 1)
        }
        let mean = ac.reduce(0, +) / Double(ac.count)
        let std = (ac.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(ac.count)).squareRoot()
        guard std > 1e-5 else { return nil }
        let thr = 0.35 * std

        var peaks: [Double] = []
        var last = -1.0
        for i in 1..<(ac.count - 1) where ac[i] > thr && ac[i] >= ac[i - 1] && ac[i] > ac[i + 1] {
            if last < 0 || times[i] - last > 0.33 {   // refractory: max ~180 bpm
                peaks.append(times[i]); last = times[i]
            }
        }
        guard peaks.count >= 5 else { return nil }
        let intervals = zip(peaks.dropFirst(), peaks).map { $0 - $1 }.sorted()
        let median = intervals[intervals.count / 2]
        guard median > 0 else { return nil }
        let bpm = Int((60.0 / median).rounded())
        return (40...180).contains(bpm) ? bpm : nil
    }
}
