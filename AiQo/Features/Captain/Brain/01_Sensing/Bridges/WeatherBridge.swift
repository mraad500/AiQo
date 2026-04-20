import Foundation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Read-only weather context for cultural / temporal triggers.
/// Stubbed until BATCH 7 (Cultural / Persona) wires a real WeatherKit provider.
enum WeatherBridge {
    struct Current: Sendable, Equatable {
        let temperatureCelsius: Int
        let condition: Condition
        let isDaytime: Bool
    }

    enum Condition: String, Sendable, Equatable {
        case clear
        case cloudy
        case rainy
        case snowy
        case stormy
        case hot
        case unknown
    }

    /// Placeholder — real implementation will use WeatherKit (requires entitlement).
    static func current() async -> Current? {
        nil
    }
}
