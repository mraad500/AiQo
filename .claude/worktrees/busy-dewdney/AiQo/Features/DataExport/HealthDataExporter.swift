import Foundation
import UIKit
import PDFKit

/// يصدّر بيانات الصحة كـ PDF أو CSV — للمستخدم أو للطبيب
@MainActor
final class HealthDataExporter {

    // MARK: - CSV Export

    /// يصدّر بيانات أسبوع كـ CSV
    static func exportWeeklyCSV(data: WeeklyReportData) -> URL? {
        var csv = "المقياس,القيمة,الوحدة,الأسبوع الماضي,التغيير %\n"
        csv += "الخطوات,\(data.totalSteps),خطوة,\(data.previousSteps),\(String(format: "%.1f", data.stepsChange))%\n"
        csv += "السعرات,\(data.totalCalories),kcal,\(data.previousCalories),\(String(format: "%.1f", data.caloriesChange))%\n"
        csv += "المسافة,\(String(format: "%.2f", data.totalDistanceKm)),كم,\(String(format: "%.2f", data.previousDistanceKm)),\(String(format: "%.1f", data.distanceChange))%\n"
        csv += "النوم,\(String(format: "%.1f", data.totalSleepHours)),ساعة,\(String(format: "%.1f", data.previousSleepHours)),\(String(format: "%.1f", data.sleepChange))%\n"
        csv += "الماء,\(String(format: "%.1f", data.totalWaterLiters)),لتر,\(String(format: "%.1f", data.previousWaterLiters)),\(String(format: "%.1f", data.waterChange))%\n"
        csv += "التمارين,\(data.workoutCount),تمرين,\(data.previousWorkoutCount),\(String(format: "%.1f", data.workoutChange))%\n"
        csv += "\nالنتيجة الإجمالية,\(data.overallScore),/ 100,,\n"
        csv += "\nالخطوات اليومية\n"
        csv += "اليوم,الخطوات,السعرات\n"
        for i in 0..<min(data.dailySteps.count, data.dailyCalories.count) {
            let date = Calendar.current.date(byAdding: .day, value: i, to: data.weekStartDate)!
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            csv += "\(formatter.string(from: date)),\(data.dailySteps[i]),\(data.dailyCalories[i])\n"
        }

        return saveToTemp(content: csv, filename: "AiQo_Weekly_\(dateStamp()).csv")
    }

    // MARK: - PDF Export

    /// يصدّر تقرير PDF جميل
    static func exportWeeklyPDF(data: WeeklyReportData, userName: String) -> URL? {
        let pageWidth: CGFloat = 595.0   // A4
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 40.0
        let contentWidth = pageWidth - (margin * 2)

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        UIGraphicsBeginPDFPage()
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        var yPos: CGFloat = margin

        // ـــــ الهيدر ـــــ
        yPos = drawHeader(at: yPos, width: contentWidth, margin: margin, userName: userName, data: data)

        // ـــــ النتيجة ـــــ
        yPos = drawScoreSection(at: yPos, width: contentWidth, margin: margin, context: context, data: data)

        // ـــــ الإحصائيات ـــــ
        yPos = drawStatsTable(at: yPos, width: contentWidth, margin: margin, data: data)

        // ـــــ الخطوات اليومية ـــــ
        yPos = drawDailyChart(at: yPos, width: contentWidth, margin: margin, context: context, data: data)

        // ـــــ الفوتر ـــــ
        drawFooter(pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)

        UIGraphicsEndPDFContext()

        let filename = "AiQo_Weekly_\(dateStamp()).pdf"
        guard let tempURL = saveDataToTemp(data: pdfData as Data, filename: filename) else { return nil }
        return tempURL
    }

    // MARK: - Share

    /// يفتح Share Sheet مع الملف
    static func share(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        activityVC.popoverPresentationController?.sourceView = rootVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)

        rootVC.present(activityVC, animated: true)
    }

    // MARK: - PDF Drawing Helpers

    private static func drawHeader(at y: CGFloat, width: CGFloat, margin: CGFloat, userName: String, data: WeeklyReportData) -> CGFloat {
        var yPos = y

        // لوقو
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: UIColor.black
        ]
        let title = "AiQo" as NSString
        title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttrs)
        yPos += 38

        // اسم المستخدم
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        let name = userName as NSString
        name.draw(at: CGPoint(x: margin, y: yPos), withAttributes: nameAttrs)
        yPos += 24

        // التاريخ
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "d MMM yyyy"
        let dateRange = "\(formatter.string(from: data.weekStartDate)) — \(formatter.string(from: data.weekEndDate))"
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        (dateRange as NSString).draw(at: CGPoint(x: margin, y: yPos), withAttributes: dateAttrs)
        yPos += 20

        // خط فاصل
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: yPos))
        line.addLine(to: CGPoint(x: margin + width, y: yPos))
        UIColor.lightGray.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        yPos += 20

        return yPos
    }

    private static func drawScoreSection(at y: CGFloat, width: CGFloat, margin: CGFloat, context: CGContext, data: WeeklyReportData) -> CGFloat {
        var yPos = y

        let sectionTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        ("النتيجة الإجمالية" as NSString).draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionTitle)
        yPos += 30

        // دائرة النتيجة
        let centerX = margin + width / 2
        let radius: CGFloat = 45
        let ringWidth: CGFloat = 8

        // الخلفية
        context.setStrokeColor(UIColor.systemGray5.cgColor)
        context.setLineWidth(ringWidth)
        context.addArc(center: CGPoint(x: centerX, y: yPos + radius), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.strokePath()

        // التقدم
        let progress = CGFloat(data.overallScore) / 100.0
        let startAngle: CGFloat = -.pi / 2
        let endAngle = startAngle + (.pi * 2 * progress)
        let mintColor = UIColor(red: 0.718, green: 0.890, blue: 0.792, alpha: 1)
        context.setStrokeColor(mintColor.cgColor)
        context.setLineWidth(ringWidth)
        context.setLineCap(.round)
        context.addArc(center: CGPoint(x: centerX, y: yPos + radius), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        context.strokePath()

        // الرقم
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .black),
            .foregroundColor: UIColor.black
        ]
        let scoreText = "\(data.overallScore)" as NSString
        let scoreSize = scoreText.size(withAttributes: scoreAttrs)
        scoreText.draw(at: CGPoint(x: centerX - scoreSize.width / 2, y: yPos + radius - scoreSize.height / 2), withAttributes: scoreAttrs)

        yPos += radius * 2 + 30
        return yPos
    }

    private static func drawStatsTable(at y: CGFloat, width: CGFloat, margin: CGFloat, data: WeeklyReportData) -> CGFloat {
        var yPos = y

        let sectionTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        ("الإحصائيات" as NSString).draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionTitle)
        yPos += 30

        let stats: [(String, String, String, Double)] = [
            ("🏃", "الخطوات", formatNumber(data.totalSteps), data.stepsChange),
            ("🔥", "السعرات", "\(data.totalCalories) kcal", data.caloriesChange),
            ("📏", "المسافة", String(format: "%.1f كم", data.totalDistanceKm), data.distanceChange),
            ("😴", "النوم", String(format: "%.1f ساعة", data.totalSleepHours), data.sleepChange),
            ("💧", "الماء", String(format: "%.1f لتر", data.totalWaterLiters), data.waterChange),
            ("💪", "التمارين", "\(data.workoutCount) تمرين", data.workoutChange)
        ]

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor.black
        ]

        for (emoji, label, value, change) in stats {
            let row = "\(emoji)  \(label)" as NSString
            row.draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttrs)

            (value as NSString).draw(at: CGPoint(x: margin + 160, y: yPos), withAttributes: valueAttrs)

            let changeText = change >= 0 ? "+\(String(format: "%.0f", change))%" : "\(String(format: "%.0f", change))%"
            let changeColor = change >= 0 ? UIColor.systemGreen : UIColor.systemRed
            let changeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: changeColor
            ]
            (changeText as NSString).draw(at: CGPoint(x: margin + 350, y: yPos + 1), withAttributes: changeAttrs)

            yPos += 28
        }

        yPos += 10
        return yPos
    }

    private static func drawDailyChart(at y: CGFloat, width: CGFloat, margin: CGFloat, context: CGContext, data: WeeklyReportData) -> CGFloat {
        var yPos = y

        let sectionTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        ("الخطوات اليومية" as NSString).draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionTitle)
        yPos += 30

        let chartHeight: CGFloat = 100
        let barCount = data.dailySteps.count
        guard barCount > 0 else { return yPos }

        let maxValue = max(data.dailySteps.max() ?? 1, 1)
        let barWidth = (width - CGFloat(barCount - 1) * 8) / CGFloat(barCount)

        let mintColor = UIColor(red: 0.718, green: 0.890, blue: 0.792, alpha: 1)

        for i in 0..<barCount {
            let barHeight = CGFloat(data.dailySteps[i]) / CGFloat(maxValue) * chartHeight
            let x = margin + CGFloat(i) * (barWidth + 8)
            let barY = yPos + chartHeight - barHeight

            let barRect = CGRect(x: x, y: barY, width: barWidth, height: barHeight)
            let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: 4)
            context.setFillColor(mintColor.cgColor)
            context.addPath(barPath.cgPath)
            context.fillPath()

            // اسم اليوم
            let date = Calendar.current.date(byAdding: .day, value: i, to: data.weekStartDate)!
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "ar")
            dayFormatter.dateFormat = "EE"
            let dayName = String(dayFormatter.string(from: date).prefix(2))
            let dayAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor.gray
            ]
            let daySize = (dayName as NSString).size(withAttributes: dayAttrs)
            (dayName as NSString).draw(at: CGPoint(x: x + barWidth / 2 - daySize.width / 2, y: yPos + chartHeight + 4), withAttributes: dayAttrs)
        }

        yPos += chartHeight + 30
        return yPos
    }

    private static func drawFooter(pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.lightGray
        ]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let footerText = "Generated by AiQo • \(formatter.string(from: Date()))" as NSString
        let footerSize = footerText.size(withAttributes: footerAttrs)
        footerText.draw(
            at: CGPoint(x: pageWidth / 2 - footerSize.width / 2, y: pageHeight - margin),
            withAttributes: footerAttrs
        )
    }

    // MARK: - Utilities

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private static func saveToTemp(content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("❌ Failed to save CSV: \(error)")
            return nil
        }
    }

    private static func saveDataToTemp(data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ Failed to save PDF: \(error)")
            return nil
        }
    }
}
