import SwiftUI

@MainActor
struct GalaxyCanvasView: View {
    @ObservedObject var viewModel: GalaxyViewModel

    var body: some View {
        ConstellationCanvasView(viewModel: viewModel)
    }
}
