import Foundation
extension Date {
    var startOfDayUTC: Date { Calendar.current.startOfDay(for: self) }
}
