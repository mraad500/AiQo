import SwiftUI
import WidgetKit
internal import Combine

class CoinManager: ObservableObject {
    static let shared = CoinManager()
    
    @Published var balance: Int = 0 {
        didSet {
            // الحفظ باستخدام مفتاح المجموعة
            UserDefaults(suiteName: AppGroupKeys.appGroupID)?.set(balance, forKey: AppGroupKeys.userCoins)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private init() {
        // التحميل عند البدء
        self.balance = UserDefaults(suiteName: AppGroupKeys.appGroupID)?.integer(forKey: AppGroupKeys.userCoins) ?? 0
    }
    
    func addCoins(_ amount: Int) {
        balance += amount
        print("💰 Added: \(amount). New Balance: \(balance)")
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        if balance >= amount {
            balance -= amount
            print("💸 Spent: \(amount). Remaining: \(balance)")
            return true
        }
        return false
    }
}
