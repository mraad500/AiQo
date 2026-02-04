import SwiftUI
import FamilyControls

struct ContentView: View {

    @EnvironmentObject var model: ProtectionModel
    
    // 👇 ربطنا مدير العملات هنا
    @ObservedObject var coinManager = CoinManager.shared

    // Picker
    @State private var showPicker = false
    
    // Alerts
    @State private var showNotEnoughCoinsAlert = false

    var body: some View {
        VStack(spacing: 25) {

            // 1) Top indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            // 2) Title
            Text("Bio-Digital Kernel")
                .font(.headline)
                .padding(.top, 5)

            Spacer().frame(height: 10)

            // 3) Icon & Balance 💰
            ZStack {
                // الخلفية المشعة
                Circle()
                    .fill(Color.yellow.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .blur(radius: 10)
                
                VStack(spacing: 5) {
                    Image(systemName: model.isEnabled ? "lock.shield.fill" : "lock.open.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(model.isEnabled ? .green : .orange)
                    
                    // عرض الرصيد
                    HStack(spacing: 5) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("\(coinManager.balance)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    Text("AiQo Coins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)

            // 4) Protection status
            Text(model.isEnabled ? "Protection Active" : "Paused")
                .font(.title3)
                .bold()
                .foregroundStyle(model.isEnabled ? .green : .secondary)

            // 5) Selection details
            Text(selectionCountText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 10)

            // 6) Pick apps
            Button {
                showPicker = true
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text("Edit Blocked Apps")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $model.selection)

            // 7) Marketplace Logic 🛒
            if model.isEnabled {
                // اذا الحماية شغالة، اعرض خيارات الشراء
                VStack(spacing: 12) {
                    Text("Unlock Time with Coins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 12) {
                        // خيار 15 دقيقة
                        buyButton(minutes: 15, cost: 30, color: .orange)
                        
                        // خيار 1 ساعة
                        buyButton(minutes: 60, cost: 100, color: .purple)
                    }
                }
            } else {
                // اذا الحماية طافية، زر التفعيل المجاني
                Button {
                    model.enable()
                } label: {
                    HStack {
                        Image(systemName: "shield.fill")
                        Text("Activate Protection")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.4), radius: 5, x: 0, y: 3)
                }
                .disabled(!model.isAuthorized)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .onAppear {
            model.refreshAuthorization()
        }
        .alert("Not Enough Coins! 🏃‍♂️", isPresented: $showNotEnoughCoinsAlert) {
            Button("I'll Walk More", role: .cancel) { }
        } message: {
            Text("You need more AiQo Coins. Go for a run or walk to mine more!")
        }

        // ✅ Emergency Button (Red Dot) - زر الطوارئ السري
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    if model.isEnabled {
                        model.disable()
                    }
                } label: {
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 8, height: 8)
                        .padding(20)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .background(Color.clear)
        }
    }
    
    // تصميم زر الشراء
    private func buyButton(minutes: Int, cost: Int, color: Color) -> some View {
        Button {
            // محاولة الشراء
            if coinManager.spendCoins(cost) {
                model.unlockTemporarily(minutes: minutes)
            } else {
                showNotEnoughCoinsAlert = true
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(minutes) Min")
                    .font(.headline)
                    .foregroundStyle(color)
                
                HStack(spacing: 2) {
                    Text("\(cost)")
                        .bold()
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var selectionCountText: String {
        let apps = model.selection.applicationTokens.count
        let categories = model.selection.categoryTokens.count
        let web = model.selection.webDomainTokens.count
        return "Apps: \(apps) | Categories: \(categories) | Web: \(web)"
    }
}
