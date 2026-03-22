import SwiftUI

/// شاشة تفاصيل التحدي الكاملة — تظهر لما المستخدم يضغط على تحدي
@MainActor
struct ArenaChallengeDetailView: View {
    let challenge: TribeChallenge
    let members: [TribeMember]
    let onContribute: () -> Void
    let onDismiss: () -> Void

    @State private var showConfetti = false
    @State private var animateRing = false

    private var progress: Double {
        guard challenge.targetValue > 0 else { return 0 }
        return min(Double(challenge.progressValue) / Double(challenge.targetValue), 1.0)
    }

    private var isCompleted: Bool { progress >= 1.0 }

    private var timeRemaining: String {
        let interval = challenge.endAt.timeIntervalSince(Date())
        if interval <= 0 { return "انتهى" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            return "\(days) يوم"
        } else if hours > 0 {
            return "\(hours) ساعة \(minutes) دقيقة"
        } else {
            return "\(minutes) دقيقة"
        }
    }

    var body: some View {
        ZStack {
            // الخلفية
            TribeGalaxyBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ـــ الهيدر ـــ
                    headerSection

                    // ـــ حلقة التقدم ـــ
                    progressRingSection

                    // ـــ الإحصائيات ـــ
                    statsGrid

                    // ـــ الليدربورد ـــ
                    if !members.isEmpty {
                        leaderboardSection
                    }

                    // ـــ زر المساهمة ـــ
                    if !isCompleted {
                        contributeButton
                    } else {
                        completedBanner
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }

            // الكونفيتي
            if showConfetti {
                ArenaConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animateRing = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            // أيقونة
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [metricColor, metricColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: challenge.metricType.iconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: metricColor.opacity(0.4), radius: 12, y: 4)

            Text(challenge.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Label(challenge.scope.title, systemImage: scopeIcon)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Text("•")
                    .foregroundStyle(.white.opacity(0.3))

                Label(challenge.cadence.title, systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                if challenge.participantsCount > 1 {
                    Text("•")
                        .foregroundStyle(.white.opacity(0.3))

                    Label("\(challenge.participantsCount)", systemImage: "person.2.fill")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Progress Ring

    private var progressRingSection: some View {
        ZStack {
            // الخلفية
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 14)
                .frame(width: 180, height: 180)

            // التقدم
            Circle()
                .trim(from: 0, to: animateRing ? progress : 0)
                .stroke(
                    AngularGradient(
                        colors: [metricColor, metricColor.opacity(0.6), metricColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("\(challenge.progressValue)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("/ \(challenge.targetValue) \(challenge.metricType.unitLabel)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(metricColor)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        TribeGlassCard(cornerRadius: 24, padding: 16, tint: Color.white.opacity(0.02)) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 14) {
                statCell(
                    icon: "clock.fill",
                    value: timeRemaining,
                    label: "الوقت المتبقي",
                    tint: .orange
                )

                statCell(
                    icon: "flame.fill",
                    value: "\(challenge.metricType.defaultIncrement)",
                    label: "لكل مساهمة",
                    tint: .red
                )

                statCell(
                    icon: "person.2.fill",
                    value: "\(challenge.participantsCount)",
                    label: "مشاركين",
                    tint: .blue
                )
            }
        }
    }

    private func statCell(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        TribeGlassCard(cornerRadius: 24, padding: 16, tint: Color.white.opacity(0.02)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.orange)

                    Text("المتصدرين")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                ForEach(Array(members.prefix(5).enumerated()), id: \.offset) { index, member in
                    leaderboardRow(rank: index + 1, member: member)
                }
            }
        }
    }

    private func leaderboardRow(rank: Int, member: TribeMember) -> some View {
        HStack(spacing: 12) {
            // الترتيب
            ZStack {
                Circle()
                    .fill(rankColor(rank).opacity(0.15))
                    .frame(width: 32, height: 32)

                Text(rankEmoji(rank))
                    .font(.system(size: 14))
            }

            // الاسم
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("المستوى \(member.level.arabicFormatted)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // النقاط
            Text("\(member.auraEnergyToday)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(rankColor(rank))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Contribute Button

    private var contributeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onContribute()

            // تحقق إذا خلص التحدي
            let newProgress = challenge.progressValue + challenge.metricType.defaultIncrement
            if newProgress >= challenge.targetValue {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showConfetti = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    showConfetti = false
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))

                Text("ساهم +\(challenge.metricType.defaultIncrement) \(challenge.metricType.unitLabel)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [metricColor, metricColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: metricColor.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var completedBanner: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: isCompleted)

            Text("مكتمل! 🎉")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("أحسنت! أكملت التحدي بنجاح")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private var metricColor: Color {
        Color(hue: challenge.metricType.accentHue, saturation: 0.6, brightness: 0.9)
    }

    private var scopeIcon: String {
        switch challenge.scope {
        case .personal: return "person.fill"
        case .tribe: return "person.3.fill"
        case .galaxy: return "sparkles"
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .orange
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return .white.opacity(0.5)
        }
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }
}

// MARK: - Confetti

struct ArenaConfettiView: View {
    @State private var particles: [ConfettiParticle] = (0..<50).map { _ in ConfettiParticle() }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x * size.width,
                        y: particle.y * size.height,
                        width: particle.size,
                        height: particle.size
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            animateParticles()
        }
    }

    private func animateParticles() {
        withAnimation(.linear(duration: 3)) {
            for i in particles.indices {
                particles[i].y = 1.2
                particles[i].x += Double.random(in: -0.2...0.2)
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double = Double.random(in: 0...1)
    var y: Double = Double.random(in: -0.3...0)
    let size: CGFloat = CGFloat.random(in: 4...8)
    let color: Color = [
        Color.orange, Color.green, Color.blue, Color.purple,
        Color.pink, Color.yellow, Color.mint
    ].randomElement() ?? .white
}
