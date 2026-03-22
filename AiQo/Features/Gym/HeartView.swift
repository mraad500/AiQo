import SwiftUI

// MARK: V2 - Post Launch — Heart rate monitor feature planned for future release
struct HeartView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red.opacity(0.4))
                .padding()
            Text("Heart Rate Monitor")
                .font(.title2.bold())
            Text("Coming Soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
