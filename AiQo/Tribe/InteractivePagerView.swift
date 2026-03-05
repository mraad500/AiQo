import SwiftUI

struct InteractivePagerView<Content: View>: View {
    let pageCount: Int
    @Binding var selection: Int
    @Binding var progress: CGFloat
    @ViewBuilder var content: (Int) -> Content

    @Environment(\.layoutDirection) private var layoutDirection
    @GestureState private var dragX: CGFloat = 0

    init(
        pageCount: Int,
        selection: Binding<Int>,
        progress: Binding<CGFloat>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.pageCount = max(pageCount, 1)
        _selection = selection
        _progress = progress
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)

            HStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { idx in
                    content(idx)
                        .frame(width: w)
                        .environment(\.layoutDirection, layoutDirection)
                }
            }
            .frame(width: w * CGFloat(pageCount), alignment: .leading)
            .offset(x: baseOffset(width: w) + dragX)
            .clipped()
            .contentShape(Rectangle())
            .environment(\.layoutDirection, .leftToRight)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .updating($dragX) { value, state, _ in
                        guard isHorizontal(value.translation) else {
                            state = 0
                            return
                        }
                        state = value.translation.width
                        updateProgress(width: w, drag: value.translation.width)
                    }
                    .onChanged { value in
                        guard isHorizontal(value.translation) else { return }
                        updateProgress(width: w, drag: value.translation.width)
                    }
                    .onEnded { value in
                        guard isHorizontal(value.translation) else { return }
                        finish(width: w, drag: value.translation.width, predicted: value.predictedEndTranslation.width)
                    }
            )
            .onAppear {
                progress = CGFloat(selection)
            }
            .onChange(of: selection) { _, newValue in
                // Tap from segmented control -> snap page, animate progress to integer
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    progress = CGFloat(newValue)
                }
            }
        }
    }

    private func baseOffset(width: CGFloat) -> CGFloat {
        -CGFloat(selection) * width
    }

    private func updateProgress(width: CGFloat, drag: CGFloat) {
        // selection - (drag/width) gives continuous progress
        let raw = CGFloat(selection) - (drag / width)
        progress = min(max(raw, 0), CGFloat(pageCount - 1))
    }

    private func finish(width: CGFloat, drag: CGFloat, predicted: CGFloat) {
        // iOS-ish: use a bit of predicted end to decide page
        let projected = drag + (predicted - drag) * 0.25
        let raw = CGFloat(selection) - (projected / width)
        let clamped = min(max(raw, 0), CGFloat(pageCount - 1))
        let target = Int(round(clamped))

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            selection = target
            progress = CGFloat(target)
        }
    }

    private func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }
}
