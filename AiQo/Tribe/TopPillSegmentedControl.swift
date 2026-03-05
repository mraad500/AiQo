import SwiftUI
import UIKit

struct TopPillSegmentedControl: View {
    let titles: [String]
    @Binding var selection: Int
    let progress: CGFloat
    let trailingReservedWidth: CGFloat

    init(
        titles: [String] = ["القبيلة", "الارينا", "العالمي"],
        selection: Binding<Int>,
        progress: CGFloat,
        trailingReservedWidth: CGFloat = 0
    ) {
        self.titles = titles
        _selection = selection
        self.progress = progress
        self.trailingReservedWidth = trailingReservedWidth
    }

    var body: some View {
        NativeTopSegmentedControl(
            titles: titles,
            selection: $selection,
            progress: progress,
            trailingReservedWidth: trailingReservedWidth
        )
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }
}

private struct NativeTopSegmentedControl: UIViewRepresentable {
    let titles: [String]
    @Binding var selection: Int
    let progress: CGFloat
    let trailingReservedWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> NativeTopSegmentedContainerView {
        let view = NativeTopSegmentedContainerView()
        view.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            DispatchQueue.main.async {
                guard context.coordinator.selection != index else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    context.coordinator.selection = index
                }
            }
        }
        return view
    }

    func updateUIView(_ uiView: NativeTopSegmentedContainerView, context: Context) {
        uiView.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            DispatchQueue.main.async {
                guard context.coordinator.selection != index else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    context.coordinator.selection = index
                }
            }
        }
        uiView.update(
            titles: titles,
            selection: selection,
            progress: progress,
            trailingReservedWidth: trailingReservedWidth
        )
    }

    final class Coordinator {
        @Binding var selection: Int

        init(selection: Binding<Int>) {
            _selection = selection
        }
    }
}

private final class NativeTopSegmentedContainerView: UIView {
    private let segmentedControl = UISegmentedControl(items: [])
    private var trailingConstraint: NSLayoutConstraint!
    private var cachedTitles: [String] = []

    var onSelectionChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear
        semanticContentAttribute = .forceLeftToRight

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.semanticContentAttribute = .forceLeftToRight
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmentedControl.addTarget(self, action: #selector(valueChanged(_:)), for: .valueChanged)
        addSubview(segmentedControl)

        trailingConstraint = segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor)
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingConstraint,
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor),
            segmentedControl.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    func update(
        titles: [String],
        selection: Int,
        progress: CGFloat,
        trailingReservedWidth: CGFloat
    ) {
        if titles != cachedTitles {
            cachedTitles = titles
            rebuildSegments(with: titles)
        }

        trailingConstraint.constant = -max(0, trailingReservedWidth)

        guard !titles.isEmpty else { return }
        let nearestToProgress = Int(round(progress))
        let clampedProgressIndex = min(max(nearestToProgress, 0), titles.count - 1)
        let clampedSelection = min(max(selection, 0), titles.count - 1)

        // Keep native segmented synced during drag and after snap.
        let targetIndex = abs(progress - CGFloat(clampedSelection)) < 0.51 ? clampedSelection : clampedProgressIndex
        if segmentedControl.selectedSegmentIndex != targetIndex {
            segmentedControl.selectedSegmentIndex = targetIndex
        }
    }

    @objc
    private func valueChanged(_ sender: UISegmentedControl) {
        onSelectionChanged?(sender.selectedSegmentIndex)
    }

    private func rebuildSegments(with titles: [String]) {
        segmentedControl.removeAllSegments()
        for (index, title) in titles.enumerated() {
            segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TopPillSegmentedControl(selection: .constant(0), progress: 0, trailingReservedWidth: 62)
        TopPillSegmentedControl(selection: .constant(1), progress: 1, trailingReservedWidth: 62)
    }
    .padding()
}
