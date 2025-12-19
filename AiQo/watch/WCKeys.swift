import Foundation

// MARK: - Protocol Versioning
enum WCProtocol {
    static let version: Int = 1
}

// MARK: - Envelope Keys (Outer wrapper)
enum WCEnvelopeKey: String {
    case v
    case kind
    case payload
}

// MARK: - Message Kinds (Top-level routing)
enum WCMessageKind: String, Codable {
    case ping
    case command
    case workoutState
    case liveMetrics
    case error
}

// MARK: - Payload Keys (Inner payload dictionary)
enum WCPayloadKey: String {
    case command
    case workoutID
    case activityType
    case locationType
    case startDate
    case endDate

    case metricsData
    case state
    case errorMessage

    case text
    case timestamp
}

// MARK: - Dictionary helpers
extension Dictionary where Key == String, Value == Any {

    static func wcEnvelope(kind: WCMessageKind, payload: [String: Any]) -> [String: Any] {
        [
            WCEnvelopeKey.v.rawValue: WCProtocol.version,
            WCEnvelopeKey.kind.rawValue: kind.rawValue,
            WCEnvelopeKey.payload.rawValue: payload
        ]
    }

    func wcDecodeEnvelope() -> (kind: WCMessageKind, payload: [String: Any], version: Int)? {
        guard
            let kindRaw = self[WCEnvelopeKey.kind.rawValue] as? String,
            let kind = WCMessageKind(rawValue: kindRaw),
            let payload = self[WCEnvelopeKey.payload.rawValue] as? [String: Any]
        else { return nil }

        let version = self[WCEnvelopeKey.v.rawValue] as? Int ?? 0
        return (kind, payload, version)
    }
}

// MARK: - JSON Data codec
enum WCCoding {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
