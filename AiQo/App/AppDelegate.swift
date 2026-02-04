// =====================================================
// File: iOS/AppDelegate.swift
// Target: iOS
// =====================================================

import UIKit
import UserNotifications
import FamilyControls
import WatchConnectivity

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 1. تفعيل WatchConnectivity
        _ = PhoneConnectivityManager.shared
        print("🚀 WC Activated from AppDelegate (via Singleton init)")

        // 2. إعداد مركز الإشعارات
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // 3. طلب الصلاحيات من المستخدم
        NotificationService.shared.requestPermissions()

        // 4. تسجيل التطبيق لاستلام الإشعارات عن بعد
        application.registerForRemoteNotifications()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // إعادة تعيين شارة الأيقونة (Badge) إلى صفر عند فتح التطبيق
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // MARK: - Remote Notifications Registration

    // ✅ دالة نجاح التسجيل: استلام التوكن وإرساله للخدمة
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ Device Token Retrieved: \(token)")
        
        // التعديل الجديد: نرسل التوكن ليتم حفظه محلياً ومزامنته
        SupabaseService.shared.updateDeviceToken(token)
    }

    // دالة فشل التسجيل
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // ✅ دالة استلام الإشعار في الخلفية (Background Fetch)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📩 Received remote notification: \(userInfo)")
        
        // معالجة البيانات القادمة
        NotificationService.shared.handleRemoteNotification(userInfo: userInfo)
        
        completionHandler(.newData)
    }

    // MARK: - UNUserNotificationCenterDelegate

    // التعامل مع الإشعار والتطبيق مفتوح
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // التعامل مع ضغط المستخدم على الإشعار
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationService.shared.handle(response: response)
        completionHandler()
    }
}
