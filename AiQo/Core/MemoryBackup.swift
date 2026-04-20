import Foundation
import SwiftData

enum MemoryBackupError: LocalizedError {
    case notImplemented

    var errorDescription: String? {
        "V3 memory snapshot export is not implemented yet."
    }
}

enum MemoryBackup {
    static func exportV3Snapshot() throws -> Data {
        throw MemoryBackupError.notImplemented
    }
}
