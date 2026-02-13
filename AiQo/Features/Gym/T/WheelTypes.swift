import Foundation

enum WheelState: Equatable {
    case idle
    case expanded
    case spinning
    case resultShown
}

enum MediaMode: Equatable {
    case none
    case songs
    case video
}
