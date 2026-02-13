import SwiftUI

struct HeartView: View {
    var body: some View {
        VStack {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
                .padding()
            Text("Heart Rate Monitor")
                .font(.title2.bold())
            Text("Coming Soon")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
