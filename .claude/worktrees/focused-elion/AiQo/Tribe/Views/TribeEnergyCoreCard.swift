import SwiftUI
import UIKit

struct TribeEnergyCoreCard: View {
    let progressValue: Int
    let targetValue: Int
    let headline: String
    let statusLine: String

    private var clampedProgress: Int {
        max(0, min(progressValue, targetValue))
    }

    private var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(clampedProgress) / Double(targetValue), 1)
    }

    var body: some View {
        TribeGlassPanel(style: .soft, tint: Colors.mint) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(TribePalette.progressTrack, lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            TribePalette.progressFill,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(clampedProgress)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("/ \(targetValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("tribe.hub.energy.description".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ProgressView(value: progress)
                        .tint(TribePalette.progressFill)

                    Text(statusLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

enum TribeGlassPanelStyle {
    case glass
    case soft
}

struct TribeGlassPanel<Content: View>: View {
    let style: TribeGlassPanelStyle
    let tint: UIColor
    @ViewBuilder let content: Content

    init(
        style: TribeGlassPanelStyle = .soft,
        tint: UIColor = .white,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background {
                TribeGlassBackground(style: style, tint: tint)
            }
    }
}

private struct TribeGlassBackground: UIViewRepresentable {
    let style: TribeGlassPanelStyle
    let tint: UIColor

    func makeUIView(context: Context) -> UIView {
        switch style {
        case .glass:
            let view = GlassCardView()
            view.isUserInteractionEnabled = false
            view.setTint(tint)
            return view
        case .soft:
            let view = SoftGlassCardView()
            view.isUserInteractionEnabled = false
            view.setTint(tint, intensity: 0.16)
            return view
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let glassView = uiView as? GlassCardView {
            glassView.setTint(tint)
        } else if let softGlassView = uiView as? SoftGlassCardView {
            softGlassView.setTint(tint, intensity: 0.16)
        }
    }
}
