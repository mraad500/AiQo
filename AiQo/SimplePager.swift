// SimplePager.swift
import SwiftUI

struct SimplePager<Content: View>: View {
    let pageCount: Int
    @Binding var selection: Int
    /// Interactive progress 0...(pageCount-1)
    @Binding var progress: CGFloat
    @ViewBuilder let content: () -> Content

    @GestureState private var dragX: CGFloat = 0

    init(
        pageCount: Int,
        selection: Binding<Int>,
        progress: Binding<CGFloat>,
        @ViewBuilder content: @escaping () -> Content
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
                content()
                    .frame(width: w)
            }
            .frame(width: w * CGFloat(pageCount), alignment: .leading)
            .offset(x: offsetX(width: w))
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .updating($dragX) { value, state, _ in
                        state = value.translation.width
                        updateProgressInteractively(width: w, drag: value.translation.width)
                    }
                    .onChanged { value in
                        updateProgressInteractively(width: w, drag: value.translation.width)
                    }
                    .onEnded { value in
                        finishDrag(width: w, drag: value.translation.width, predicted: value.predictedEndTranslation.width)
                    }
            )
            .onAppear {
                progress = CGFloat(selection)
            }
            .onChange(of: selection) { _, newValue in
                // If selection changed by tap, snap pages
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    progress = CGFloat(newValue)
                }
            }
        }
        .clipped()
    }

    private func offsetX(width: CGFloat) -> CGFloat {
        // Base offset for current selection plus interactive drag
        let base = -CGFloat(selection) * width
        return base + dragX
    }

    private func updateProgressInteractively(width: CGFloat, drag: CGFloat) {
        let raw = CGFloat(selection) - (drag / width)
        let clamped = min(max(raw, 0), CGFloat(pageCount - 1))
        progress = clamped
    }

    private func finishDrag(width: CGFloat, drag: CGFloat, predicted: CGFloat) {
        // Use predicted end to feel like iOS
        let projected = drag + (predicted - drag) * 0.25
        let raw = CGFloat(selection) - (projected / width)
        let target = Int(round(min(max(raw, 0), CGFloat(pageCount - 1))))

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            selection = target
            progress = CGFloat(target)
        }
    }
}
