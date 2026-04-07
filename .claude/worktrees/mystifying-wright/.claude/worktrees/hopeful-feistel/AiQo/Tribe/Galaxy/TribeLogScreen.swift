// Supabase hook: replace `previewEvents` with timeline records fetched from the
// Tribe activity feed when the log endpoint is wired up.
import SwiftUI

struct TribeLogScreen: View {
    private let events = previewEvents

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TribeGlassCard(cornerRadius: 28, padding: 16, tint: Color.white.opacity(0.02)) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("السجل")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("آخر 10 أحداث داخل القبيلة.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            ForEach(events) { event in
                TribeGlassCard(cornerRadius: 24, padding: 14, tint: Color.white.opacity(0.018)) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: event.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(event.detail)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))

                            Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.46))
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

private let previewEvents: [GalaxyLogEvent] = {
    let now = Date()

    return [
        GalaxyLogEvent(id: "log-1", iconName: "person.2.fill", title: "انضم عضو جديد", detail: "ليان انضمت إلى القبيلة", timestamp: now.addingTimeInterval(-60 * 22)),
        GalaxyLogEvent(id: "log-2", iconName: "sparkles", title: "تم إرسال شرارة", detail: "أرسلت شرارة إلى عضو من المدار الداخلي", timestamp: now.addingTimeInterval(-60 * 48)),
        GalaxyLogEvent(id: "log-3", iconName: "flag.checkered", title: "اكتمل تحدٍ يومي", detail: "تم إنهاء تحدي 50,000 خطوة اليوم", timestamp: now.addingTimeInterval(-60 * 80)),
        GalaxyLogEvent(id: "log-4", iconName: "drop.fill", title: "تحديث قبلي", detail: "زادت مساهمات الماء إلى 28 كوب", timestamp: now.addingTimeInterval(-60 * 135)),
        GalaxyLogEvent(id: "log-5", iconName: "moon.stars.fill", title: "هدوء جديد", detail: "بدأ تحدي دقائق هدوء 60", timestamp: now.addingTimeInterval(-60 * 180)),
        GalaxyLogEvent(id: "log-6", iconName: "crown.fill", title: "تبدل المراكز", detail: "المركز الأول انتقل إلى ليان", timestamp: now.addingTimeInterval(-60 * 260)),
        GalaxyLogEvent(id: "log-7", iconName: "bolt.heart.fill", title: "طاقة متدفقة", detail: "وصلت طاقة القبيلة إلى +320", timestamp: now.addingTimeInterval(-60 * 340)),
        GalaxyLogEvent(id: "log-8", iconName: "figure.walk", title: "دفعة خطوات", detail: "ارتفعت خطوات التحدي الشهري", timestamp: now.addingTimeInterval(-60 * 420)),
        GalaxyLogEvent(id: "log-9", iconName: "star.fill", title: "انطلقت مهمة مجرية", detail: "AiQo أضافت تحديًا شهريًا جديدًا", timestamp: now.addingTimeInterval(-60 * 510)),
        GalaxyLogEvent(id: "log-10", iconName: "bell.fill", title: "تذكير المدار", detail: "تبقى ساعات قليلة على تحديات اليوم", timestamp: now.addingTimeInterval(-60 * 640))
    ]
}()

#Preview {
    ZStack {
        TribeGalaxyBackground()

        ScrollView(showsIndicators: false) {
            TribeLogScreen()
                .padding(16)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
