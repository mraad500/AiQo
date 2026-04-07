import SwiftUI

@MainActor
struct TribeScreen: View {
    init(allowsPreviewAccess: Bool = false) { }

    var body: some View {
        TribeView()
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        TribeScreen()
    }
}
