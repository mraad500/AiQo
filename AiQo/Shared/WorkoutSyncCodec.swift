import Foundation

nonisolated enum WorkoutSyncCodec {
    nonisolated private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    nonisolated private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    nonisolated static func encode(_ payload: WorkoutSyncPayload) throws -> Data {
        try makeEncoder().encode(payload)
    }

    nonisolated static func decode(_ data: Data) throws -> WorkoutSyncPayload {
        try makeDecoder().decode(WorkoutSyncPayload.self, from: data)
    }

    nonisolated static func encodeCompanionMessage(_ message: WorkoutCompanionMessage) throws -> Data {
        try makeEncoder().encode(message)
    }

    nonisolated static func decodeCompanionMessage(_ data: Data) throws -> WorkoutCompanionMessage {
        try makeDecoder().decode(WorkoutCompanionMessage.self, from: data)
    }
}
