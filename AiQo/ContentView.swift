import SwiftUI
import FamilyControls

struct ContentView: View {

    // 👇 التغيير المهم: حولناها إلى EnvironmentObject حتى تستلم النسخة المشتركة
    @EnvironmentObject var model: ProtectionModel
    
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // الأيقونة والحالة
                Image(systemName: model.isEnabled ? "lock.shield.fill" : "lock.open")
                    .font(.system(size: 70))
                    .foregroundStyle(model.isEnabled ? .red : .green)
                    .contentTransition(.symbolEffect(.replace)) // حركة حلوة اذا انت iOS 17+

                Text(model.isEnabled ? "الحماية مفعّلة" : "الحماية مطفّية")
                    .font(.title)
                    .bold()

                // ملخص الاختيار
                Text(model.selectionSummary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Divider()
                    .padding(.vertical)

                // زر طلب الصلاحية (يظهر فقط اذا ماكو صلاحية)
                if !model.isAuthorized {
                    Button {
                        Task {
                            await model.requestAuthorization()
                        }
                    } label: {
                        Text("طلب صلاحية Screen Time")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                // زر اختيار التطبيقات
                Button {
                    showPicker = true
                } label: {
                    Label("تعديل التطبيقات المحظورة", systemImage: "square.stack.3d.up.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .familyActivityPicker(
                    isPresented: $showPicker,
                    selection: $model.selection
                )

                // زر التشغيل
                if !model.isEnabled {
                    Button {
                        model.enable()
                    } label: {
                        Text("تفعيل المراقبة (بعد 1 دقيقة)")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!model.canEnable || !model.isAuthorized)
                }
                // زر الإيقاف
                else {
                    Button(role: .destructive) {
                        model.disable()
                    } label: {
                        Text("إيقاف الحماية")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            // 👇 غيرنا الاسم من mohammed1 الى اسم ميزتك
            .navigationTitle("Bio-Digital Kernel")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // تحديث الحالة أول ما تفتح الشاشة
                model.refreshAuthorization()
            }
        }
    }
}
