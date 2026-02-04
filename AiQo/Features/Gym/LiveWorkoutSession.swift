// ===============================================
// File: LiveWorkoutSession.swift
// ===============================================

import Foundation
import HealthKit
import SwiftUI
import UIKit // ⚠️ ضروري لتشغيل الاهتزاز (Haptic)
internal import Combine

@MainActor
final class LiveWorkoutSession: ObservableObject {
    
    // حالات التمرين
    enum Phase: Equatable {
        case idle       // خامل
        case starting   // جاري الاتصال
        case running    // قيد التشغيل
        case paused     // متوقف
        case ending     // إنهاء
    }

    let activityType: HKWorkoutActivityType
    let locationType: HKWorkoutSessionLocationType
    
    // مدير الاتصال
    private let connectivity = PhoneConnectivityManager.shared
    
    // MARK: - Public State
    
    @Published var title: String = "Gym Workout"
    @Published var phase: Phase = .idle
    
    // البيانات الحية (تُحدث الواجهة فورياً)
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: Int = 0
    
    @Published var isWatchReachable: Bool = false
    
    // ✅ متغيرات الإشعار الجديد (يظهر عند اكتمال كل 1 كم)
    @Published var showMilestoneAlert: Bool = false
    @Published var milestoneAlertText: String = ""
    
    // متغير محلي لتتبع آخر كيلومتر تم تسجيله (لمنع تكرار الاهتزاز لنفس الكيلو)
    private var lastRecordedKm: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // نص الحالة للعرض
    var statusText: String {
        switch phase {
        case .idle: return "Ready"
        case .starting: return "Connecting..."
        case .running: return "Active"
        case .paused: return "Paused"
        case .ending: return "Saving..."
        }
    }
    
    var canStart: Bool { phase == .idle }
    var canEnd: Bool { phase == .running || phase == .paused }
    var canPause: Bool { phase == .running }
    var canResume: Bool { phase == .paused }
    
    // MARK: - Init
    
    init(
        title: String = "Gym Workout",
        activityType: HKWorkoutActivityType = .other,
        locationType: HKWorkoutSessionLocationType = .unknown
    ) {
        self.title = title
        self.activityType = activityType
        self.locationType = locationType
        
        setupBindings()
    }

    // MARK: - Bindings (ربط البيانات)
    
    private func setupBindings() {
        
        connectivity.$isReachable
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$isWatchReachable)
        
        connectivity.$currentHeartRate
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$heartRate)
            
        connectivity.$activeEnergy
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$activeEnergy)
            
        // ✅ هنا التعديل: نراقب المسافة لعمل الاهتزاز والإشعار
        connectivity.$currentDistance
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] distance in
                guard let self = self else { return }
                self.distanceMeters = distance
                self.checkForMilestone(totalMeters: distance)
            }
            .store(in: &cancellables)
            
        connectivity.$currentDuration
            .receive(on: RunLoop.main)
            .map { Int($0) }
            .removeDuplicates()
            .assign(to: &$elapsedSeconds)
    }

    // ✅ دالة التحقق من الكيلومترات (تعمل بصمت: اهتزاز فقط)
    private func checkForMilestone(totalMeters: Double) {
        // حساب الكيلومتر الحالي (مثلاً 1500 متر = 1 كم)
        let currentKm = Int(totalMeters / 1000)
        
        // الشرط: قطعنا كيلو جديد + لم يتم تنبيه المستخدم عنه مسبقاً
        if currentKm > 0 && currentKm > lastRecordedKm {
            lastRecordedKm = currentKm
            
            // 1. تحديث نص الإشعار وإظهاره
            withAnimation(.spring()) {
                self.milestoneAlertText = "\(currentKm) km ✅"
                self.showMilestoneAlert = true
            }
            
            // 2. تشغيل الاهتزاز (Haptic Feedback) - صامت
            let generator = UINotificationFeedbackGenerator()
            generator.prepare() // تجهيز المحرك لتقليل التأخير
            generator.notificationOccurred(.success)
            
            print("📱 Phone Vibrated for: \(currentKm) km")
            
            // 3. إخفاء الإشعار تلقائياً بعد 3 ثوانٍ
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    self.showMilestoneAlert = false
                }
            }
        }
    }

    // MARK: - Controls
    
    func startFromPhone() {
        guard canStart else { return }
        
        // تصفير العدادات عند بدء تمرين جديد
        lastRecordedKm = 0
        showMilestoneAlert = false
        
        withAnimation { phase = .starting }
        
        print("🚀 Launching Watch App...")
        connectivity.launchWatchAppForWorkout(activityType: activityType, locationType: locationType)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectivity.startWorkoutOnWatch(
                activityTypeRaw: Int(self.activityType.rawValue),
                locationTypeRaw: Int(self.locationType.rawValue)
            )
            withAnimation(.snappy) { self.phase = .running }
        }
    }
    
    func pauseFromPhone() {
        guard canPause else { return }
        withAnimation(.snappy) { phase = .paused }
    }
    
    func resumeFromPhone() {
        guard canResume else { return }
        withAnimation(.snappy) { phase = .running }
    }
    
    func endFromPhone() {
        guard canEnd else { return }
        withAnimation(.snappy) { phase = .ending }
        
        connectivity.stopWorkoutOnWatch()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.snappy) {
                self.phase = .idle
                self.heartRate = 0
                self.activeEnergy = 0
                self.distanceMeters = 0
                self.elapsedSeconds = 0
                // تصفير حالة الإشعار
                self.lastRecordedKm = 0
                self.showMilestoneAlert = false
            }
        }
    }
}
