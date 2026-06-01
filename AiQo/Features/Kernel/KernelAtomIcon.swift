import SwiftUI
import Foundation

/// Animated «النواة» (Kernel) atom icon. Palette + line weight are matched to the
/// Daily Aura ring (mint `#A3DBCF`, gold `#E8C996` — the exact colors
/// `DailyAuraView` strokes with), and the three electrons orbit slowly along the
/// tilted rings. Drawn with `Canvas` + `TimelineView(.animation)` so it actually
/// moves in-app (iOS asset catalogs rasterize SVG/PNG and can't animate).
struct KernelAtomIcon: View {
    var size: CGFloat = 100

    // Daily Aura palette (source of truth: DailyAuraView).
    private let mint = Color(red: 0.64, green: 0.86, blue: 0.81)     // #A3DBCF
    private let gold = Color(red: 0.91, green: 0.79, blue: 0.59)     // #E8C996
    private let deepMint = Color(red: 0.369, green: 0.804, blue: 0.718) // #5ECDB7
    private let deepGold = Color(red: 0.878, green: 0.741, blue: 0.455) // #E0BD74

    /// (tilt°, ring color, electron color, seconds per revolution — very slow so
    /// the motion is calm and never dizzying).
    private var orbits: [(tilt: Double, ring: Color, electron: Color, period: Double)] {
        [(0, mint, deepMint, 58), (60, gold, deepGold, 74), (120, mint, deepMint, 50)]
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let rx = sz.width * 0.42
                let ry = sz.width * 0.16
                let lineW = sz.width * 0.045   // ≈ Daily Aura line weight
                let t = timeline.date.timeIntervalSinceReferenceDate

                // Orbital rings (rotated ellipses).
                for orbit in orbits {
                    let ellipse = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
                    let tf = CGAffineTransform(translationX: c.x, y: c.y)
                        .rotated(by: orbit.tilt * .pi / 180)
                        .translatedBy(x: -c.x, y: -c.y)
                    ctx.stroke(ellipse.applying(tf), with: .color(orbit.ring.opacity(0.9)),
                               style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                }

                // Core glow + glowing nucleus.
                let glowR = sz.width * 0.17
                ctx.fill(
                    circle(at: c, r: glowR),
                    with: .radialGradient(Gradient(colors: [mint.opacity(0.5), mint.opacity(0)]),
                                          center: c, startRadius: 0, endRadius: glowR)
                )
                let coreR = sz.width * 0.095
                ctx.fill(
                    circle(at: c, r: coreR),
                    with: .radialGradient(
                        Gradient(colors: [Color(red: 0.92, green: 0.99, blue: 0.96), deepMint]),
                        center: CGPoint(x: c.x - coreR * 0.3, y: c.y - coreR * 0.3),
                        startRadius: 0, endRadius: coreR * 1.4)
                )

                // Electrons riding the rings.
                for orbit in orbits {
                    let a = (t / orbit.period) * 2 * .pi
                    let ex = rx * cos(a), ey = ry * sin(a)
                    let rot = orbit.tilt * .pi / 180
                    let p = CGPoint(x: c.x + ex * cos(rot) - ey * sin(rot),
                                    y: c.y + ex * sin(rot) + ey * cos(rot))
                    let er = sz.width * 0.05
                    ctx.fill(circle(at: p, r: er), with: .color(orbit.electron))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func circle(at p: CGPoint, r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    }
}
