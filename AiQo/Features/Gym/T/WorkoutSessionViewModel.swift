import SwiftUI
internal import Combine

// MARK: - Data Models
// عرفنا الموديل هنا حتى يختفي خطأ "Cannot find type WorkoutVideo"
struct WorkoutVideo: Identifiable {
    let id = UUID()
    let category: String
    let videoID: String
}

// MARK: - View Model
class WorkoutSessionViewModel: ObservableObject {
    
    // MARK: - Workout Metrics
    @Published var elapsedSeconds: Int = 0
    @Published var heartRate: Int = 122
    @Published var calories: Int = 87
    @Published var distance: Double = 1.26
    @Published var isRunning: Bool = false
    
    // MARK: - Wheel & Media State
    @Published var wheelState: WheelState = .idle
    @Published var selectedMedia: MediaMode = .none
    @Published var rotationAngle: Double = 0
    
    // ✅ هذه القائمة كانت ناقصة وسببت المشاكل، الآن ضفناها
    @Published var workoutVideos: [WorkoutVideo] = [
        WorkoutVideo(category: "HIIT", videoID: "m44z-J1bB3A"),
        WorkoutVideo(category: "Yoga", videoID: "sTANio_2E0Q"),
        WorkoutVideo(category: "Core", videoID: "dJlFmxiL11s"),
        WorkoutVideo(category: "Stretching", videoID: "g_tea8ZNk5A"),
        WorkoutVideo(category: "Cardio", videoID: "ml6cT4AZdqI"),
        WorkoutVideo(category: "Strength", videoID: "fAt616Fw9Zk")
    ]
    
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
        
        // حساب زاوية دوران عشوائية
        // نختار عشوائياً بين تشغيل فيديو أو أغاني
        let randomChoice = Bool.random() // True = Songs, False = Video
        
        // حساب الزاوية لضمان الوقوف في مكان صحيح (تقريبي)
        let targetAngle = randomChoice ? 360.0 * 5 + 90 : 360.0 * 5 + 270
        
        // تنفيذ الدوران
        withAnimation(.easeOut(duration: 3.0)) {
            rotationAngle += targetAngle
        }
        
        // بعد انتهاء الدوران (3 ثواني) نعرض النتيجة
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut) {
                // هنا نحدد شنو النتيجة اللي طلعت
                self.selectedMedia = randomChoice ? .songs : .video
                
                // نغير الحالة حتى تختفي العجلة ويظهر المحتوى
                self.wheelState = .resultShown
            }
        }
    }
    
    // MARK: - Timer Helpers
    private func startTimer() {
        // تأكدنا من عدم تكرار التايمر
        stopTimer()
        
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.elapsedSeconds += 1
                
                // محاكاة تغيير البيانات الحيوية لجعلها تبدو حقيقية
                if self.elapsedSeconds % 5 == 0 {
                    withAnimation {
                        self.heartRate = Int.random(in: 115...135)
                        self.calories += 1
                    }
                }
                self.distance += 0.005
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
