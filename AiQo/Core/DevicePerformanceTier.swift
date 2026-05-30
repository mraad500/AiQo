import Foundation

/// Decides whether expensive 3D / cinematic rendering should run at full fidelity
/// on this device *right now*.
///
/// Two inputs:
///  - **Static device class** — `ProcessInfo.physicalMemory`. Devices with less
///    than ~5 GB RAM (iPhone 12/13 non-Pro, SE, and older) are treated as
///    lower-end for sustained 3D work (realistic-elevation satellite map +
///    pitched chase camera + RealityKit avatar).
///  - **Live thermal state** — `ProcessInfo.thermalState`. Once the device hits
///    `.serious` or `.critical`, fidelity drops on *any* device so we stop
///    feeding the thermal spiral (battery drain, frame drops, OS throttling).
///
/// Gated overall by `HIGH_FIDELITY_3D_ENABLED` (default ON) so the behavior can
/// be force-disabled from Info.plist. Nothing is ever removed — callers fall
/// back to a lighter rendering (flat map elevation, fixed camera, 2D avatar),
/// never to "no feature".
enum DevicePerformanceTier {
    /// RAM threshold separating 4 GB devices (lower-end) from 6 GB+ devices.
    /// 4 GB reports ~4.29e9 bytes; 6 GB reports ~6.44e9 — 5 GB cleanly splits them.
    private static let lowerEndMemoryCeiling: UInt64 = 5 * 1024 * 1024 * 1024

    /// True on devices with limited RAM for sustained high-fidelity 3D.
    static var isLowerEndDevice: Bool {
        ProcessInfo.processInfo.physicalMemory < lowerEndMemoryCeiling
    }

    /// True when the device is thermally stressed and should shed GPU load now.
    static var isThermallyStressed: Bool {
        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical: return true
        case .nominal, .fair: return false
        @unknown default: return false
        }
    }

    /// The single decision callers read. High fidelity only when the flag is ON,
    /// the device is capable, and it isn't currently overheating.
    static var shouldUseHighFidelity3D: Bool {
        guard FeatureFlags.highFidelity3DEnabled else { return false }
        if isThermallyStressed { return false }
        if isLowerEndDevice { return false }
        return true
    }
}
