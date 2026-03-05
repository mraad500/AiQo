import SwiftUI

/// واجهة تعرض 5 مسارات بيضاوية متقاطعة تشترك في نفس المركز الهندسي
struct TribeOrbitsView: View {
    // مصفوفة تحتوي على قيم التقدم (من 0.0 إلى 1.0) لكل مسار
    var memberProgresses: [CGFloat]
    
    // مصفوفة تحتوي على الألوان الخاصة بكل مسار
    let orbitColors: [Color]
    
    var body: some View {
        // نستخدم ZStack بمركز ثابت لضمان عدم تحرك الأشكال
        ZStack(alignment: .center) {
            
            // 1. الهالة الخارجية (Outer Aura)
            Circle()
                .stroke(
                    Color(red: 0.85, green: 0.75, blue: 0.55), // لون بيج/ذهبي ناعم
                    style: StrokeStyle(lineWidth: 3, dash: [12, 18])
                )
                .frame(width: 240, height: 240)
            
            // 2. المسارات البيضاوية الخمسة (5 Intersecting Ellipses)
            ForEach(0..<5, id: \.self) { index in
                // التحقق من وجود القيم في المصفوفة لتجنب أي أخطاء (Out of Bounds)
                let progress = memberProgresses.indices.contains(index) ? memberProgresses[index] : 0.0
                let color = orbitColors.indices.contains(index) ? orbitColors[index] : .gray
                
                Ellipse()
                    // تطبيق القص بناءً على قيمة التقدم
                    .trim(from: 0, to: progress)
                    // رسم الحدود باللون المحدد وحواف دائرية
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    // أداة الحل الأساسية: إطار ثابت تماماً للشكل البيضاوي قبل تدويره
                    .frame(width: 200, height: 70)
                    // التدوير بزيادة 72 درجة لكل مسار حول المركز الدقيق
                    .rotationEffect(.degrees(Double(index) * 72.0), anchor: .center)
            }
        }
        // تغليف نهائي بإطار ثابت يمنع الإزاحة ويقوم بتثبيت الحجم الإجمالي
        .frame(width: 240, height: 240)
        // إضافة الحركة (Animation) المطلوبة عند تغير قيم التقدم
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: memberProgresses)
    }
}

// MARK: - Preview
#Preview {
    // عرض تجريبي يثبت دقة المركز واختلاف قيم التقدم (Trim)
    TribeOrbitsView(
        memberProgresses: [0.2, 0.4, 0.6, 0.8, 1.0],
        orbitColors: [
            .red,
            .blue,
            .green,
            .orange,
            .purple
        ]
    )
}
