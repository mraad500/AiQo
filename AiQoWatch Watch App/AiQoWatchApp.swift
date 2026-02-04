import SwiftUI

@main
struct AiQoWatchApp: App {
    // نستخدم StateObject حتى نضمن ان الكائن يبقى موجود طول فترة حياة التطبيق
    @StateObject private var workoutManager = WorkoutManager.shared
    
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                // ✅ هنا التغيير: نفحص اذا اكو تمرين شغال لو لا
                if workoutManager.running {
                    // اذا التمرين شغال، اعرض شاشة العدادات والتحكم
                    // تأكد ان عندك View اسمه SessionPagingView او ControlsView
                    SessionPagingView()
                        .environmentObject(workoutManager)
                } else {
                    // اذا ماكو تمرين، اعرض القائمة
                    StartView()
                        .environmentObject(workoutManager)
                }
            }
            // هذا السطر مهم حتى الـ Summary يظهر
            .sheet(isPresented: $workoutManager.showingSummaryView) {
                SummaryView()
                    .environmentObject(workoutManager)
            }
            .onAppear {
                workoutManager.requestAuthorization()
            }
        }
    }
}
