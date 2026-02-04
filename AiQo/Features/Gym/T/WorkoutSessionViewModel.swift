//
//  WorkoutSessionViewModel.swift
//  (Create New File)
//

import SwiftUI
internal import Combine

enum WheelState {
    case idle           // صغيرة وساكنة
    case expanded       // مكبرة مع الدبوس
    case spinning       // تدور
    case resultShown    // اختفت وظهرت الميديا
}

enum MediaMode {
    case none
    case songs
    case video
}

class WorkoutSessionViewModel: ObservableObject {
    
    // MARK: - Workout Data
    @Published var elapsedSeconds: Int = 0
    @Published var heartRate: Int = 122
    @Published var calories: Int = 87
    @Published var distance: Double = 1.26
    @Published var isRunning: Bool = false
    
    // MARK: - Wheel & Media State
    @Published var wheelState: WheelState = .idle
    @Published var selectedMedia: MediaMode = .none
    @Published var rotationAngle: Double = 0
    
    private var timer: AnyCancellable?
    
    // تنسيق الوقت (00:00)
    var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d : %02d", m, s)
    }
    
    // MARK: - Actions
    
    func toggleWorkout() {
        isRunning.toggle()
        if isRunning {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    // منطق العجلة (Spin Wheel Logic)
    func handleWheelTap() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            switch wheelState {
            case .idle:
                // الضغطة الأولى: تكبير
                wheelState = .expanded
                
            case .expanded:
                // الضغطة الثانية: تدوير
                spinWheel()
                
            default:
                break
            }
        }
    }
    
    private func spinWheel() {
        wheelState = .spinning
        
        // حساب زاوية دوران عشوائية (للوقوف إما على Songs أو Video)
        // لنفترض أن العجلة مقسومة نصفين. سنقوم بعمل دورات كاملة + زاوية الهدف.
        let randomChoice = Bool.random() // True = Songs, False = Video
        let targetAngle = randomChoice ? 360.0 * 5 + 90 : 360.0 * 5 + 270 // زوايا تقريبية
        
        // تدوير العجلة
        withAnimation(.easeOut(duration: 3.0)) {
            rotationAngle += targetAngle
        }
        
        // بعد انتهاء الدوران
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut) {
                self.selectedMedia = randomChoice ? .songs : .video
                self.wheelState = .resultShown
            }
        }
    }
    
    // MARK: - Private Helpers
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
                // محاكاة تغيير البيانات
                self?.heartRate = Int.random(in: 110...130)
                self?.calories += 1
                self?.distance += 0.01
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
    }
}
