import SwiftUI
import FamilyControls

struct PermissionView: View {
    @EnvironmentObject var model: ProtectionModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))

            Text("صلاحية المراقبة")
                .font(.title).bold()

            Text("حتى نراقب التطبيقات المحددة ونفعل الدرع بعد دقيقة استخدام.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("طلب الصلاحية")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Button {
                model.refreshAuthorization()
            } label: {
                Text("تحديث الحالة")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
        .padding()
    }
}
