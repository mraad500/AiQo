import UIKit
import AVFoundation
import HealthKit

/// شاشة قياس نبض القلب بالكاميرا (ليست أداة طبية)
final class HeartViewController: UIViewController { // تم التعديل من BaseViewController لضمان التوافق اذا لم يكن موجوداً

    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "قياس نبض القلب"
        label.font = UIFont.systemFont(ofSize: 28, weight: .heavy)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "غطّ الكاميرا الخلفية بإصبعك حتى تمتلئ الدائرة باللون"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let emojiHeartLabel: UILabel = {
        let label = UILabel()
        label.text = "❤"
        label.font = .systemFont(ofSize: 44, weight: .regular)
        label.textAlignment = .center
        return label
    }()

    /// دائرة الكاميرا (مصغّرة)
    private let circlePreview: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemRed.withAlphaComponent(0.5)
        v.layer.cornerRadius = 60
        v.layer.masksToBounds = true
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.7).cgColor
        return v
    }()

    private let bpmLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        label.font = UIFont.systemFont(ofSize: 44, weight: .heavy)
        label.textAlignment = .center
        return label
    }()

    private let bpmUnitLabel: UILabel = {
        let label = UILabel()
        label.text = "BPM"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

    private let toggleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("ابدأ القياس", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        btn.backgroundColor = .systemGreen
        btn.tintColor = .white
        btn.layer.cornerRadius = 18
        return btn
    }()

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "هذه الأداة ليست لأغراض طبية أو تشخيصية"
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

    // MARK: - Camera / Signal

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private let processingQueue = DispatchQueue(label: "aiqo.heart.camera")

    private var isMeasuring = false

    // قيم الإشارة
    private var lastFilteredValue: Double = 0
    private var lastDerivative: Double = 0

    /// أزمنة النبضات (نحتفظ بآخر 12 نبضة فقط)
    private var beatTimestamps: [Double] = []

    /// آخر قيمة BPM معتبرة (منعّمة)
    private var lastValidBPM: Int?

    /// سلسلة القيم المفلترة لحساب المتوسط
    private var recentValues: [Double] = []

    /// لكل جلسة حتى نحفظ قراءة واحدة فقط في HealthKit
    private var didSaveCurrentMeasurement = false

    /// أقل مدة مقبولة للجلسة
    private let minimumMeasurementDuration: TimeInterval = 10 // ثواني

    /// بداية الجلسة
    private var measurementStartDate: Date?

    /// عتبة تذبذب الإضاءة (للتأكد أن الإصبع ثابت)
    private let varianceThreshold: Double = 0.03
    
    // استخدام HealthKitService (تأكد من وجود الملف)
    // private let healthService = HealthKitService.shared
    // ^ علقتها مؤقتاً لتجنب الأخطاء اذا الملف غير موجود، فعلها اذا عندك الملف

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildLayout()

        toggleButton.addTarget(self,
                               action: #selector(toggleMeasurement),
                               for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = circlePreview.bounds
        circlePreview.layer.cornerRadius = circlePreview.bounds.width / 2
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMeasuring {
            stopMeasurement()
        }
    }

    /// تحويل آخر BPM إلى نقاط مستوى
    private func finishHeartMeasurement(finalBPM: Int) {
        // ✅ تم الإصلاح: استخدام addXP بدلاً من addPoints
        LevelStore.shared.addXP(amount: finalBPM)
        print("Done! Added \(finalBPM) XP to LevelStore")
    }

    // MARK: - Layout

    private func buildLayout() {
        let bpmStack = UIStackView(arrangedSubviews: [bpmLabel, bpmUnitLabel])
        bpmStack.axis = .vertical
        bpmStack.alignment = .center
        bpmStack.spacing = 2

        [titleLabel,
         subtitleLabel,
         emojiHeartLabel,
         circlePreview,
         bpmStack,
         toggleButton,
         hintLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            emojiHeartLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            emojiHeartLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            circlePreview.topAnchor.constraint(equalTo: emojiHeartLabel.bottomAnchor, constant: 10),
            circlePreview.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            circlePreview.widthAnchor.constraint(equalToConstant: 110),
            circlePreview.heightAnchor.constraint(equalTo: circlePreview.widthAnchor),

            bpmStack.topAnchor.constraint(equalTo: circlePreview.bottomAnchor, constant: 20),
            bpmStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            toggleButton.topAnchor.constraint(equalTo: bpmStack.bottomAnchor, constant: 28),
            toggleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            toggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            toggleButton.heightAnchor.constraint(equalToConstant: 54),

            hintLabel.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 10),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func toggleMeasurement() {
        if isMeasuring {
            stopMeasurement()
        } else {
            Task { await startMeasurementFlow() }
        }
    }

    // MARK: - Flow

    private func startMeasurementFlow() async {
        // _ = try? await healthService.requestAuthorization() // فعلها اذا عندك HealthKit

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            startMeasurement()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            granted ? startMeasurement() : showCameraDenied()
        default:
            showCameraDenied()
        }
    }

    private func showCameraDenied() {
        subtitleLabel.text = "صلاحية الكاميرا مرفوضة. فعّلها من الإعدادات لاستخدام قياس النبض."
    }

    private func startMeasurement() {
        guard !isMeasuring else { return }

        isMeasuring = true
        didSaveCurrentMeasurement = false
        measurementStartDate = Date()

        beatTimestamps.removeAll()
        recentValues.removeAll()
        lastFilteredValue = 0
        lastDerivative = 0
        lastValidBPM = nil
        bpmLabel.text = "--"

        subtitleLabel.text = "غطّ الكاميرا الخلفية بإصبعك، وحاول ما تتحرك 15–20 ثانية."
        toggleButton.setTitle("إيقاف القياس", for: .normal)
        toggleButton.backgroundColor = .systemRed

        startHeartEmojiAnimation(bpm: 70)
        configureSessionIfNeeded()

        processingQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            DispatchQueue.main.async { self.setTorch(on: true) }
        }
    }

    private func stopMeasurement() {
        guard isMeasuring else { return }

        isMeasuring = false

        processingQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async { self.setTorch(on: false) }
        }

        toggleButton.setTitle("ابدأ القياس", for: .normal)
        toggleButton.backgroundColor = .systemGreen
        stopHeartEmojiAnimation()

        let duration: TimeInterval = measurementStartDate.map { Date().timeIntervalSince($0) } ?? 0
        measurementStartDate = nil

        if let bpm = lastValidBPM, duration >= minimumMeasurementDuration {
            // قياس ناجح
            bpmLabel.text = "\(bpm)"
            updateHeartEmojiAnimation(bpm: bpm)
            // saveHeartRateIfNeeded(bpm: bpm) // فعلها اذا عندك HealthKit

            // ✅ إضافة النقاط
            finishHeartMeasurement(finalBPM: bpm)

            subtitleLabel.text = "آخر قياس تقريبي: \(bpm) نبضة في الدقيقة (ليست أداة طبية)."
        } else {
            lastValidBPM = nil
            subtitleLabel.text = "القياس كان قصير أو غير واضح. حاول مرة أخرى وثبّت إصبعك لـ 15 ثانية."
        }
    }

    // MARK: - Camera config

    private func configureSessionIfNeeded() {
        guard captureSession.inputs.isEmpty else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back) else {
            subtitleLabel.text = "ما قدرنا نستخدم الكاميرا الخلفية."
            captureSession.commitConfiguration()
            return
        }

        captureDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: processingQueue)
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
            layer.frame = circlePreview.bounds

            circlePreview.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            circlePreview.layer.addSublayer(layer)

            captureSession.commitConfiguration()
        } catch {
            captureSession.commitConfiguration()
            subtitleLabel.text = "خطأ في إعداد الكاميرا: \(error.localizedDescription)"
        }
    }

    private func setTorch(on: Bool) {
        guard let device = captureDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: 0.9)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // نطنش، مو critical
        }
    }

    // MARK: - Heart animation

    private func startHeartEmojiAnimation(bpm: Int) {
        emojiHeartLabel.layer.removeAnimation(forKey: "pulse")

        let duration = max(0.4, min(1.2, 60.0 / Double(bpm))) / 2.0
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = 1.23
        anim.duration = duration
        anim.autoreverses = true
        anim.repeatCount = .infinity

        emojiHeartLabel.layer.add(anim, forKey: "pulse")
    }

    private func stopHeartEmojiAnimation() {
        emojiHeartLabel.layer.removeAnimation(forKey: "pulse")
    }

    private func updateHeartEmojiAnimation(bpm: Int) {
        startHeartEmojiAnimation(bpm: bpm)
    }

    // MARK: - Signal Processing

    private func processSample(value: Double, variance: Double, timestamp: Double) {
        // 1) التأكد من أن الإصبع ثابت ويغطي الكاميرا
        if variance > varianceThreshold {
            DispatchQueue.main.async {
                self.bpmLabel.text = "--"
            }
            beatTimestamps.removeAll()
            recentValues.removeAll()
            lastFilteredValue = 0
            lastDerivative = 0
            lastValidBPM = nil
            return
        }

        // 2) فلتر إكسبونينشيال
        let alpha = 0.2
        let filtered = alpha * value + (1 - alpha) * lastFilteredValue

        // 3) متوسط متحرك للقيم
        recentValues.append(filtered)
        if recentValues.count > 300 {
            recentValues.removeFirst()
        }

        let mean = recentValues.reduce(0, +) / Double(recentValues.count)
        let threshold = mean + 0.0015

        // 4) الاشتقاق
        let derivative = filtered - lastFilteredValue

        // 5) كشف النبضات (قمة بعد صعود)
        if lastDerivative > 0, derivative < 0, filtered > threshold {
            beatTimestamps.append(timestamp)

            if beatTimestamps.count > 12 {
                beatTimestamps.removeFirst()
            }

            // حساب RR intervals
            if beatTimestamps.count >= 4 {
                let intervals = zip(beatTimestamps.dropFirst(), beatTimestamps)
                    .map { $0.0 - $0.1 }

                // فلترة الفترات الواقعية (تقريباً BPM 40–180)
                let validIntervals = intervals.filter { $0 > 0.33 && $0 < 1.5 }

                if validIntervals.count >= 3 {
                    // نستخدم الوسيط لتقليل تأثير القيم الشاذة
                    let sorted = validIntervals.sorted()
                    let medianInterval = sorted[sorted.count / 2]
                    let bpmRaw = Int(60.0 / medianInterval)

                    if bpmRaw > 40, bpmRaw < 180 {
                        // تنعيم بين القراءة الحالية والقديمة
                        let smoothed: Int
                        if let last = lastValidBPM {
                            let mixed = 0.7 * Double(last) + 0.3 * Double(bpmRaw)
                            smoothed = Int(mixed.rounded())
                        } else {
                            smoothed = bpmRaw
                        }

                        DispatchQueue.main.async {
                            self.lastValidBPM = smoothed
                            self.bpmLabel.text = "\(smoothed)"
                            self.updateHeartEmojiAnimation(bpm: smoothed)
                        }
                    }
                }
            }
        }

        lastFilteredValue = filtered
        lastDerivative = derivative
    }
/*
    private func saveHeartRateIfNeeded(bpm: Int) {
        guard !didSaveCurrentMeasurement else { return }
        didSaveCurrentMeasurement = true

        Task {
            try? await healthService.saveHeartRateSample(bpm: Double(bpm), date: Date())
        }
    }
 */
}

// MARK: - AVCapture Delegate

extension HeartViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return }

        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)

        var sumR: Double = 0
        var sumR2: Double = 0
        var count = 0

        let stepX = max(1, width / 8)
        let stepY = max(1, height / 8)

        for y in stride(from: 0, to: height, by: stepY) {
            let row = ptr + y * bytesPerRow
            for x in stride(from: 0, to: width, by: stepX) {
                let pixel = row + x * 4
                // قناة الأحمر
                let r = Double(pixel[2]) / 255.0
                sumR += r
                sumR2 += r * r
                count += 1
            }
        }

        guard count > 0 else { return }

        let mean = sumR / Double(count)
        let mean2 = sumR2 / Double(count)
        let variance = max(0, mean2 - mean * mean)

        // معالجة البيانات دون الرجوع للMain Thread إلا للتحديث
        guard self.isMeasuring else { return }
        self.processSample(value: mean, variance: variance, timestamp: ts)
    }
}

