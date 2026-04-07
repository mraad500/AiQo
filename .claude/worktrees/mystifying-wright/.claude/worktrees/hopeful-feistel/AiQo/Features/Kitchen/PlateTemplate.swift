import SwiftUI

typealias PlatePlacement = (x: CGFloat, y: CGFloat, scale: CGFloat, rotation: CGFloat)

enum PlateTemplate {
    case breakfastBowl
    case lunchPlate
    case dinnerPlate
    case saladBowl
    case snackBowl
    case drinkCup

    var backgroundView: AnyView {
        switch self {
        case .breakfastBowl:
            return AnyView(
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.96, blue: 0.89), Color.white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .stroke(Color.brown.opacity(0.14), lineWidth: 6)
                        .padding(4)
                    Circle()
                        .fill(Color.white.opacity(0.52))
                        .padding(12)
                }
            )
        case .lunchPlate:
            return AnyView(
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(red: 0.94, green: 0.97, blue: 0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Circle()
                        .stroke(Color.gray.opacity(0.14), lineWidth: 7)
                        .padding(3)
                    Circle()
                        .fill(Color.white.opacity(0.66))
                        .padding(13)
                }
            )
        case .dinnerPlate:
            return AnyView(
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.98, blue: 0.97), Color.white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 7)
                        .padding(3)
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .padding(14)
                }
            )
        case .saladBowl:
            return AnyView(
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.89, green: 0.97, blue: 0.90), Color.white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .stroke(Color.green.opacity(0.18), lineWidth: 7)
                        .padding(3)
                    Circle()
                        .fill(Color.white.opacity(0.64))
                        .padding(14)
                }
            )
        case .snackBowl:
            return AnyView(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(red: 0.98, green: 0.95, blue: 0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.orange.opacity(0.14), lineWidth: 6)
                        .padding(3)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.6))
                        .padding(12)
                }
            )
        case .drinkCup:
            return AnyView(
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(red: 0.93, green: 0.96, blue: 0.99)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.blue.opacity(0.16), lineWidth: 6)
                        .padding(3)
                    Circle()
                        .stroke(Color.blue.opacity(0.18), lineWidth: 5)
                        .frame(width: 26, height: 26)
                        .offset(x: 28, y: 0)
                }
            )
        }
    }

    var placements: [PlatePlacement] {
        switch self {
        case .breakfastBowl:
            return [
                (0.31, 0.32, 0.31, -18),
                (0.67, 0.30, 0.28, 16),
                (0.28, 0.57, 0.22, -8),
                (0.54, 0.54, 0.28, 10),
                (0.74, 0.58, 0.2, 18),
                (0.45, 0.74, 0.2, -4)
            ]
        case .lunchPlate:
            return [
                (0.29, 0.34, 0.3, -12),
                (0.65, 0.33, 0.31, 14),
                (0.23, 0.61, 0.21, -15),
                (0.51, 0.58, 0.24, 4),
                (0.76, 0.58, 0.21, 12),
                (0.46, 0.78, 0.19, -8)
            ]
        case .dinnerPlate:
            return [
                (0.33, 0.31, 0.28, -14),
                (0.65, 0.35, 0.29, 16),
                (0.28, 0.56, 0.21, -6),
                (0.52, 0.54, 0.25, 8),
                (0.73, 0.58, 0.2, 15),
                (0.48, 0.76, 0.18, -12)
            ]
        case .saladBowl:
            return [
                (0.28, 0.3, 0.26, -14),
                (0.54, 0.28, 0.22, 12),
                (0.75, 0.35, 0.22, -10),
                (0.3, 0.58, 0.24, 8),
                (0.56, 0.54, 0.23, -6),
                (0.72, 0.63, 0.18, 18)
            ]
        case .snackBowl:
            return [
                (0.28, 0.34, 0.24, -10),
                (0.53, 0.32, 0.22, 14),
                (0.74, 0.36, 0.18, -12),
                (0.34, 0.62, 0.22, 8),
                (0.58, 0.6, 0.22, -8),
                (0.76, 0.64, 0.16, 14)
            ]
        case .drinkCup:
            return [
                (0.5, 0.26, 0.18, 0),
                (0.39, 0.44, 0.19, -10),
                (0.63, 0.43, 0.19, 10),
                (0.5, 0.58, 0.22, 0),
                (0.4, 0.74, 0.18, -10),
                (0.62, 0.74, 0.18, 10)
            ]
        }
    }
}
