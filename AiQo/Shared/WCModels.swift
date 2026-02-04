// اسم الملف: WCModels.swift
import Foundation

// ✅ تعريف الأوامر
public enum WCCommandType: String, Codable {
    case start
    case pause
    case resume
    case stop
}

// ✅ حمولة الأمر (Payload)
public struct WCCommandPayload: Codable {
    public let command: WCCommandType
    public let activityType: UInt // HKWorkoutActivityType rawValue
    public let locationType: Int  // HKWorkoutSessionLocationType rawValue
    
    public init(command: WCCommandType, activityType: UInt = 0, locationType: Int = 0) {
        self.command = command
        self.activityType = activityType
        self.locationType = locationType
    }
}
