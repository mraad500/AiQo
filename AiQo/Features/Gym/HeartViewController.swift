// =========================
// File: App/Localization/Localization.swift
// =========================

import UIKit

/// Minimal localization layer.
enum L10n {
    static func t(_ key: String, _ comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }

    /// Localize numbers per current locale (Arabic/Western digits).
    static func num<T: BinaryInteger>(_ n: T) -> String {
        let fmt = NumberFormatter()
        fmt.locale = .current
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: Int(n))) ?? "\(n)"
    }

    static func num(_ n: Double) -> String {
        let fmt = NumberFormatter()
        fmt.locale = .current
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: n)) ?? "\(Int(n))"
    }
}

// =========================
// File: Features/Heart/HeartViewController.swift
// =========================

import UIKit
import AVFoundation
import HealthKit

/// Heart rate with camera (non-medical)
final class HeartViewController: UIViewController {

    // MARK: - Haptic Generators
    private let beatFeedback = UIImpactFeedbackGenerator(style: .soft)
    private let successFeedback = UINotificationFeedbackGenerator()

    // MARK: - UI Elements

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.t("heart.title")
        label.font = UIFont.systemFont(ofSize: 28, weight: .heavy)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.t("heart.subtitle.initial")
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
        label.text = L10n.t("heart.bpmUnit")
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

    private let toggleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(L10n.t("heart.action.start"), for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        btn.backgroundColor = .systemGreen
        btn.tintColor = .white
        btn.layer.cornerRadius = 18
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.2
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.layer.shadowRadius = 4
        return btn
    }()
    
    // 🏆 بطاقة المكافأة (Reward Card)
    private let rewardCardView: UIVisualEffectView = {
        // تأثير زجاجي غامق (iOS 18 Style)
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: blurEffect)
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.layer.borderWidth = 1
        // إطار شبه شفاف
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.alpha = 0 // مخفية بالبداية
        return view
    }()
    
    private let rewardLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0 // نسمح بأكثر من سطر
        return label
    }()

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.t("heart.disclaimer")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

    // MARK: - Camera / Signal Variables

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private let processingQueue = DispatchQueue(label: "aiqo.heart.camera")

    private var isMeasuring = false
    private var lastFilteredValue: Double = 0
    private var lastDerivative: Double = 0
    private var beatTimestamps: [Double] = []
    private var lastValidBPM: Int?
    private var recentValues: [Double] = []
    private var didSaveCurrentMeasurement = false
    private let minimumMeasurementDuration: TimeInterval = 10
    private var measurementStartDate: Date?
    private let varianceThreshold: Double = 0.03

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildLayout()
        toggleButton.addTarget(self, action: #selector(toggleMeasurement), for: .touchUpInside)
        beatFeedback.prepare()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = circlePreview.bounds
        circlePreview.layer.cornerRadius = circlePreview.bounds.width / 2
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMeasuring { stopMeasurement() }
    }

    // MARK: - Layout Construction

    private func buildLayout() {
        let bpmStack = UIStackView(arrangedSubviews: [bpmLabel, bpmUnitLabel])
        bpmStack.axis = .vertical
        bpmStack.alignment = .center
        bpmStack.spacing = 2

        // إضافة العناصر للـ View
        [titleLabel, subtitleLabel, emojiHeartLabel, circlePreview, bpmStack, toggleButton, rewardCardView, hintLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // إعداد محتوى بطاقة المكافأة
        rewardLabel.translatesAutoresizingMaskIntoConstraints = false
        rewardCardView.contentView.addSubview(rewardLabel)
        
        NSLayoutConstraint.activate([
            // محتوى البطاقة
            rewardLabel.centerXAnchor.constraint(equalTo: rewardCardView.contentView.centerXAnchor),
            rewardLabel.centerYAnchor.constraint(equalTo: rewardCardView.contentView.centerYAnchor),
            rewardLabel.leadingAnchor.constraint(equalTo: rewardCardView.contentView.leadingAnchor, constant: 16),
            rewardLabel.trailingAnchor.constraint(equalTo: rewardCardView.contentView.trailingAnchor, constant: -16),
        ])

        // القيود (Constraints)
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
            
            // 📍 مكان بطاقة المكافأة (تحت الزر مباشرة)
            rewardCardView.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 24),
            rewardCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rewardCardView.widthAnchor.constraint(equalToConstant: 300), // زيدت العرض شوية
            rewardCardView.heightAnchor.constraint(equalToConstant: 85), // زيدت الارتفاع ليناسب النص الجديد

            // Hint Label يكون تحت بطاقة المكافأة
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
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
    
    // MARK: - Reward Display Logic 🎁
    
    private func showRewardCard(bpm: Int) {
        // 1. تجهيز النص بالتنسيق المطلوب
        // السطر الأول: Boom 🎉
        let fullText = NSMutableAttributedString(string: "Boom 🎉\n", attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .heavy),
            .foregroundColor: UIColor.label
        ])
        
        // السطر الثاني الجزء الأول: 🫀Heart Rate 77 =
        let detailsText = NSMutableAttributedString(string: "🫀Heart Rate \(bpm) = ", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ])
        
        // السطر الثاني الجزء الثاني: 77 XP 🎁 (لون أصفر)
        let xpText = NSAttributedString(string: "\(bpm) XP 🎁", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.systemYellow
        ])
        
        // السطر الثاني الجزء الثالث: | Level Up (لون أخضر)
        let levelUpText = NSAttributedString(string: " | Level Up", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.systemGreen
        ])

        // دمج النصوص
        detailsText.append(xpText)
        detailsText.append(levelUpText)
        fullText.append(detailsText)
        
        // تعيين المسافة بين الأسطر (Line Spacing) لجمالية أكثر
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .center
        fullText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: fullText.length))
        
        rewardLabel.attributedText = fullText
        
        // 2. هابتيك واهتزاز الزر
        successFeedback.notificationOccurred(.success)
        
        UIView.animate(withDuration: 0.1, animations: {
            self.toggleButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.3, initialSpringVelocity: 10, options: [], animations: {
                self.toggleButton.transform = .identity
            }, completion: nil)
        }
        
        // 3. إظهار البطاقة (Fade In + Slide Up simple)
        self.rewardCardView.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.rewardCardView.alpha = 1
            self.rewardCardView.transform = .identity
        }, completion: nil)
    }
    
    private func hideRewardCard() {
        UIView.animate(withDuration: 0.3) {
            self.rewardCardView.alpha = 0
            self.rewardCardView.transform = CGAffineTransform(translationX: 0, y: 10)
        }
    }

    // MARK: - Measurement Flow

    private func startMeasurementFlow() async {
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
        subtitleLabel.text = L10n.t("heart.subtitle.denied")
    }

    private func startMeasurement() {
        guard !isMeasuring else { return }

        // 🔴 إخفاء بطاقة المكافأة عند بدء قياس جديد
        hideRewardCard()

        isMeasuring = true
        didSaveCurrentMeasurement = false
        measurementStartDate = Date()

        beatTimestamps.removeAll()
        recentValues.removeAll()
        lastFilteredValue = 0
        lastDerivative = 0
        lastValidBPM = nil
        bpmLabel.text = "--"

        subtitleLabel.text = L10n.t("heart.subtitle.measure")
        toggleButton.setTitle(L10n.t("heart.action.stop"), for: .normal)
        toggleButton.backgroundColor = .systemRed

        startHeartEmojiAnimation(bpm: 70)
        configureSessionIfNeeded()

        processingQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning { self.captureSession.startRunning() }
            DispatchQueue.main.async { self.setTorch(on: true) }
        }
    }

    private func stopMeasurement() {
        guard isMeasuring else { return }
        isMeasuring = false

        processingQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning { self.captureSession.stopRunning() }
            DispatchQueue.main.async { self.setTorch(on: false) }
        }

        toggleButton.setTitle(L10n.t("heart.action.start"), for: .normal)
        toggleButton.backgroundColor = .systemGreen
        stopHeartEmojiAnimation()

        let duration: TimeInterval = measurementStartDate.map { Date().timeIntervalSince($0) } ?? 0
        measurementStartDate = nil

        if let bpm = lastValidBPM, duration >= minimumMeasurementDuration {
            bpmLabel.text = L10n.num(bpm)
            updateHeartEmojiAnimation(bpm: bpm)
            
            // ✅ النجاح: حفظ وعرض المكافأة الثابتة
            finishHeartMeasurement(finalBPM: bpm)
            showRewardCard(bpm: bpm)

            subtitleLabel.text = String(
                format: L10n.t("heart.subtitle.final"),
                L10n.num(bpm)
            )
        } else {
            lastValidBPM = nil
            subtitleLabel.text = L10n.t("heart.subtitle.tooShort")
        }
    }
    
    private func finishHeartMeasurement(finalBPM: Int) {
        LevelStore.shared.addXP(amount: finalBPM)
        print("Done! Added \(finalBPM) XP to LevelStore")
    }

    // MARK: - Camera config

    private func configureSessionIfNeeded() {
        guard captureSession.inputs.isEmpty else { return }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            subtitleLabel.text = L10n.t("heart.subtitle.noBackCamera")
            captureSession.commitConfiguration()
            return
        }
        captureDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) { captureSession.addInput(input) }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: processingQueue)
            if captureSession.canAddOutput(output) { captureSession.addOutput(output) }

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
            layer.frame = circlePreview.bounds

            circlePreview.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            circlePreview.layer.addSublayer(layer)

            captureSession.commitConfiguration()
        } catch {
            captureSession.commitConfiguration()
            subtitleLabel.text = String(format: L10n.t("heart.subtitle.cameraError"), error.localizedDescription)
        }
    }

    private func setTorch(on: Bool) {
        guard let device = captureDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on { try device.setTorchModeOn(level: 0.9) } else { device.torchMode = .off }
            device.unlockForConfiguration()
        } catch {
            // intentionally ignore
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
        if variance > varianceThreshold {
            DispatchQueue.main.async { self.bpmLabel.text = "--" }
            beatTimestamps.removeAll()
            recentValues.removeAll()
            lastFilteredValue = 0
            lastDerivative = 0
            lastValidBPM = nil
            return
        }

        let alpha = 0.2
        let filtered = alpha * value + (1 - alpha) * lastFilteredValue

        recentValues.append(filtered)
        if recentValues.count > 300 { recentValues.removeFirst() }

        let mean = recentValues.reduce(0, +) / Double(recentValues.count)
        let threshold = mean + 0.0015

        let derivative = filtered - lastFilteredValue

        if lastDerivative > 0, derivative < 0, filtered > threshold {
            beatTimestamps.append(timestamp)
            
            // ⚡️ Haptic Feedback
            DispatchQueue.main.async {
                self.beatFeedback.impactOccurred()
            }
            
            if beatTimestamps.count > 12 { beatTimestamps.removeFirst() }

            if beatTimestamps.count >= 4 {
                let intervals = zip(beatTimestamps.dropFirst(), beatTimestamps).map { $0.0 - $0.1 }
                let validIntervals = intervals.filter { $0 > 0.33 && $0 < 1.5 }

                if validIntervals.count >= 3 {
                    let sorted = validIntervals.sorted()
                    let medianInterval = sorted[sorted.count / 2]
                    let bpmRaw = Int(60.0 / medianInterval)

                    if bpmRaw > 40, bpmRaw < 180 {
                        let smoothed: Int
                        if let last = lastValidBPM {
                            let mixed = 0.7 * Double(last) + 0.3 * Double(bpmRaw)
                            smoothed = Int(mixed.rounded())
                        } else {
                            smoothed = bpmRaw
                        }

                        DispatchQueue.main.async {
                            self.lastValidBPM = smoothed
                            self.bpmLabel.text = L10n.num(smoothed)
                            self.updateHeartEmojiAnimation(bpm: smoothed)
                        }
                    }
                }
            }
        }

        lastFilteredValue = filtered
        lastDerivative = derivative
    }
}

extension HeartViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return }

        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        var sumR: Double = 0, sumR2: Double = 0, count = 0
        let stepX = max(1, width / 8)
        let stepY = max(1, height / 8)

        for y in stride(from: 0, to: height, by: stepY) {
            let row = ptr + y * bytesPerRow
            for x in stride(from: 0, to: width, by: stepX) {
                let pixel = row + x * 4
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

        guard self.isMeasuring else { return }
        self.processSample(value: mean, variance: variance, timestamp: ts)
    }
}
