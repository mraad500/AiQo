import SwiftUI
internal import Combine

class CoinManager: ObservableObject {
    static let shared = CoinManager()
    
    @Published var balance: Int = 0 {
        didSet {
            AppGroupKeys.defaults()?.set(balance, forKey: AppGroupKeys.userCoins)
        }
    }
    
    private init() {
        let sharedDefaults = AppGroupKeys.defaults()
        let sharedValue = sharedDefaults?.object(forKey: AppGroupKeys.userCoins) as? Int
        let legacyValue = AppGroupKeys.legacyDefaults()?.object(forKey: AppGroupKeys.userCoins) as? Int
        let resolvedBalance = sharedValue ?? legacyValue ?? 0

        if sharedValue == nil, let legacyValue {
            sharedDefaults?.set(legacyValue, forKey: AppGroupKeys.userCoins)
        }

        self.balance = resolvedBalance
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
