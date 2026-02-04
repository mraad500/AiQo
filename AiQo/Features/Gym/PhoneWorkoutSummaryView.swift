import SwiftUI
import HealthKit

// ===============================
// File: PhoneWorkoutSummaryView.swift
// ===============================

struct PhoneWorkoutSummaryView: View {

    // MARK: - Data Inputs
    let duration: TimeInterval
    let calories: Double
    let avgHeartRate: Double
    let heartRateSamples: [HKQuantitySample]

    // MARK: - State
    @State private var result: XPCalculator.XPResult?
    @State private var appearAnimation: Bool = false

    // Action
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Background (modern: stars + haze + vignette)
            SpaceBackdrop()
                .ignoresSafeArea()

            if let data = result {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {

                        // Top labels
                        VStack(spacing: 6) {
                            Text("WORKOUT SUMMARY")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .tracking(4)
                                .foregroundStyle(.white.opacity(0.35))

                            Text("WORKOUT COMPLETE")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .tracking(5)
                                .foregroundStyle(.white.opacity(0.80))
                        }
                        .padding(.top, 44)

                        // Big XP
                        VStack(spacing: 6) {
                            Text("\(data.totalXP)")
                                .font(.system(size: 118, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            .brandMint.opacity(0.95),
                                            .brandMint.opacity(0.75)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .brandMint.opacity(0.55), radius: 26, x: 0, y: 0)
                                .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 18)
                                .scaleEffect(appearAnimation ? 1.0 : 0.92)
                                .opacity(appearAnimation ? 1.0 : 0.0)

                            Text("XP EARNED")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.top, 6)

                        // Metric cards row
                        HStack(spacing: 14) {
                            ModernMetricCard(
                                title: "TIME",
                                value: formatTime(duration),
                                sub: "min",
                                icon: "stopwatch.fill",
                                delay: 0.10
                            )

                            ModernMetricCard(
                                title: "KCAL",
                                value: "\(Int(calories))",
                                sub: "cal",
                                icon: "flame.fill",
                                delay: 0.18
                            )

                            ModernMetricCard(
                                title: "AVG HR",
                                value: "\(Int(avgHeartRate))",
                                sub: "bpm",
                                icon: "heart.fill",
                                delay: 0.26
                            )
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                        // Logic container
                        LogicContainer {
                            HStack(spacing: 14) {
                                ModernLogicCard(
                                    title: "Truth Number",
                                    header: "CAL + TIME",
                                    subHeader: nil,
                                    equation: "\(data.activeCalories) + \(data.durationMinutes)",
                                    result: "\(data.truthNumber)",
                                    tint: .brandSand,
                                    delay: 0.34
                                )

                                ModernLogicCard(
                                    title: "Lucky Number",
                                    header: "Total Heartbeats",
                                    subHeader: "\(data.totalHeartbeats) HR",
                                    equation: data.heartbeatDigits.map(String.init).joined(separator: "+"),
                                    result: "\(data.luckyNumber)",
                                    tint: .brandMint,
                                    delay: 0.42
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 18)

                        // Done button (✅ تم التعديل هنا)
                        Button(action: {
                            saveXPAndDismiss(xp: data.totalXP)
                        }) {
                            Text("Done")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(.white)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 14)
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 8)
                        .padding(.bottom, 34)
                    }
                }
            } else {
                ProgressView()
                    .tint(.brandMint)
            }
        }
        .onAppear { calculateStats() }
    }

    // MARK: - Logic Execution
    private func calculateStats() {
        DispatchQueue.global(qos: .userInitiated).async {
            // ✅ افترضنا وجود كلاس XPCalculator في مشروعك كما هو
            let computedResult = XPCalculator.calculateSessionStats(
                samples: heartRateSamples,
                duration: duration,
                averageHeartRate: avgHeartRate,
                activeCalories: calories
            )
            DispatchQueue.main.async {
                self.result = computedResult
                withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                    appearAnimation = true
                }
            }
        }
    }

    // ✅ دالة جديدة: حفظ النقاط وحساب المستوى الجديد
    private func saveXPAndDismiss(xp: Int) {
        // 1. جلب البيانات الحالية
        let defaults = UserDefaults.standard
        let currentLevel = max(defaults.integer(forKey: "aiqo.currentLevel"), 1)
        let currentProgress = defaults.double(forKey: "aiqo.currentLevelProgress") // 0.0 to 1.0
        let currentTotalScore = defaults.integer(forKey: "aiqo.legacyTotalPoints")

        // 2. تحديث مجموع النقاط (Line Score)
        let newTotalScore = currentTotalScore + xp
        defaults.set(newTotalScore, forKey: "aiqo.legacyTotalPoints")

        // 3. منطق حساب المستوى (Level Up Logic)
        // لنفترض معادلة بسيطة: كل مستوى يحتاج (المستوى الحالي * 500) نقطة لملء البار
        // يمكنك تعديل الرقم 500 ليصبح أصعب أو أسهل
        var level = currentLevel
        var xpRequiredForNextLevel = Double(level * 500)
        
        // حساب الـ XP الحالي المتراكم داخل هذا المستوى فقط
        var currentXPInLevel = currentProgress * xpRequiredForNextLevel
        
        // إضافة الـ XP الجديد
        currentXPInLevel += Double(xp)
        
        // حلقة تكرار: هل تجاوزنا الحد المطلوب للمستوى التالي؟
        while currentXPInLevel >= xpRequiredForNextLevel {
            currentXPInLevel -= xpRequiredForNextLevel // نخصم تكلفة الصعود
            level += 1                                 // نرفع المستوى
            xpRequiredForNextLevel = Double(level * 500) // التكلفة للمستوى الذي يليه
        }
        
        // حساب النسبة المئوية الجديدة (0.0 - 1.0)
        let newProgress = currentXPInLevel / xpRequiredForNextLevel
        
        // 4. حفظ البيانات الجديدة
        defaults.set(level, forKey: "aiqo.currentLevel")
        defaults.set(newProgress, forKey: "aiqo.currentLevelProgress")
        
        // 5. إرسال إشعار ليعلم LevelCardView بالتحديث
        NotificationCenter.default.post(name: NSNotification.Name("XPUpdated"), object: nil)
        
        // 6. إغلاق الشاشة
        onDismiss()
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// ====================================
// MARK: - Background (Space, modern)
// ====================================

private struct SpaceBackdrop: View {
    var body: some View {
        ZStack {
            // Deep base
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft nebula/haze
            GeometryReader { geo in
                Circle()
                    .fill(Color.brandMint.opacity(0.10))
                    .frame(width: geo.size.width * 0.90, height: geo.size.width * 0.90)
                    .blur(radius: 120)
                    .position(x: geo.size.width * 0.62, y: geo.size.height * 0.34)

                Circle()
                    .fill(Color.brandSand.opacity(0.08))
                    .frame(width: geo.size.width * 0.75, height: geo.size.width * 0.75)
                    .blur(radius: 140)
                    .position(x: geo.size.width * 0.28, y: geo.size.height * 0.66)
            }

            // Starfield (Canvas)
            Starfield()
                .opacity(0.75)
                .blendMode(.screen)

            // Vignette (key for readability)
            RadialGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.70),
                    Color.black.opacity(0.92)
                ],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            .blendMode(.multiply)
        }
    }
}

private struct Starfield: View {
    var body: some View {
        Canvas { context, size in
            // Deterministic stars without random() calls per frame
            let stars: [Star] = Star.seeded(count: 140, in: size)

            for s in stars {
                var path = Path()
                path.addEllipse(in: CGRect(x: s.x, y: s.y, width: s.r, height: s.r))
                context.fill(path, with: .color(Color.white.opacity(s.a)))
            }
        }
        .ignoresSafeArea()
    }

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let r: CGFloat
        let a: CGFloat

        static func seeded(count: Int, in size: CGSize) -> [Star] {
            var out: [Star] = []
            out.reserveCapacity(count)

            // Simple deterministic generator
            var seed: UInt64 = 0xA1C020251227
            func next() -> UInt64 {
                seed = seed &* 6364136223846793005 &+ 1
                return seed
            }

            for _ in 0..<count {
                let nx = Double(next() % 10_000) / 10_000.0
                let ny = Double(next() % 10_000) / 10_000.0
                let nr = Double(next() % 1_000) / 1_000.0
                let na = Double(next() % 1_000) / 1_000.0

                let x = CGFloat(nx) * size.width
                let y = CGFloat(ny) * size.height
                let r = CGFloat(1.0 + nr * 2.2) // 1...3.2
                let a = CGFloat(0.10 + na * 0.35) // 0.10...0.45

                out.append(Star(x: x, y: y, r: r, a: a))
            }
            return out
        }
    }
}

// ====================================
// MARK: - Metric Card (modern)
// ====================================

private struct ModernMetricCard: View {
    let title: String
    let value: String
    let sub: String
    let icon: String
    let delay: Double

    @State private var show = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .padding(.top, 14)

            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text(sub)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            // Bottom indicator
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 34, height: 3)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 126)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : 0.94)
        .onAppear {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.85).delay(delay)) {
                show = true
            }
        }
    }
}

// ====================================
// MARK: - Logic Container (modern)
// ====================================

private struct LogicContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.65), radius: 26, x: 0, y: 18)
    }
}

// ====================================
// MARK: - Logic Cards (Truth / Lucky)
// ====================================

private struct ModernLogicCard: View {
    let title: String
    let header: String
    let subHeader: String?
    let equation: String
    let result: String
    let tint: Color
    let delay: Double

    @State private var show = false

    var body: some View {
        VStack(spacing: 10) {

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 6)

            VStack(spacing: 8) {
                Text(header.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 16)

                if let subHeader {
                    Text(subHeader)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                        .padding(.top, -4)
                }

                Spacer(minLength: 0)

                Text(equation)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.60)
                    .padding(.horizontal, 10)

                Spacer(minLength: 0)

                Text("= \(result)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(tint.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .opacity(show ? 1 : 0)
        .offset(y: show ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.88).delay(delay)) {
                show = true
            }
        }
    }
}
