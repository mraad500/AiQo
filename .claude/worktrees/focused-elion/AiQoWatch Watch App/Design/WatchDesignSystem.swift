import SwiftUI

// MARK: - AiQo Watch Design System
// Matches iPhone app visual identity exactly

enum AiQoWatch {

    // MARK: Card Backgrounds (same as iPhone)
    static let mintCard = Color(red: 212/255, green: 240/255, blue: 224/255)       // #D4F0E0
    static let sandCard = Color(red: 240/255, green: 221/255, blue: 179/255)       // #F0DDB3
    static let pinkCard = Color(red: 253/255, green: 224/255, blue: 224/255)       // #FDE0E0 (heart rate)

    // MARK: Icon Circle Backgrounds
    static let mintIcon = Color(red: 183/255, green: 229/255, blue: 210/255)       // #B7E5D2
    static let sandIcon = Color(red: 235/255, green: 207/255, blue: 151/255)       // #EBCF97

    // MARK: Accent Colors
    static let accent = Color(red: 94/255, green: 205/255, blue: 183/255)          // #5ECDB7
    static let accentLight = Color(red: 138/255, green: 216/255, blue: 191/255)    // #8AD8BF

    // MARK: Aura Ring Colors
    static let auraMint = Color(red: 138/255, green: 216/255, blue: 191/255)       // #8AD8BF
    static let auraSand = Color(red: 212/255, green: 184/255, blue: 122/255)       // #D4B87A

    // MARK: Backgrounds
    static let background = Color(red: 245/255, green: 247/255, blue: 251/255)     // #F5F7FB
    static let surface = Color.white
    static let ringTrack = Color(red: 232/255, green: 236/255, blue: 240/255)      // #E8ECF0

    // MARK: Text
    static let textPrimary = Color(red: 15/255, green: 23/255, blue: 33/255)       // #0F1721
    static let textSecondary = Color(red: 95/255, green: 111/255, blue: 128/255)   // #5F6F80
    static let textLight = Color(red: 138/255, green: 149/255, blue: 163/255)      // #8A95A3

    // MARK: Layout
    static let cardRadius: CGFloat = 16
    static let smallRadius: CGFloat = 12
    static let iconSize: CGFloat = 24
    static let iconRadius: CGFloat = 12
    static let cardPadding: CGFloat = 9
    static let gridSpacing: CGFloat = 5
}
