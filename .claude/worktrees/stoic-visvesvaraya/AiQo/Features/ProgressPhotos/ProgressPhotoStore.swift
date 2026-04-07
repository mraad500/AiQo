import Foundation
import UIKit
import Combine

/// يخزّن صور التقدم الجسدي محلياً — Before/After comparison
final class ProgressPhotoStore: ObservableObject {
    static let shared = ProgressPhotoStore()

    @Published private(set) var entries: [ProgressPhotoEntry] = []

    /// Pagination: number of metadata entries loaded per page
    private let pageSize = 20
    @Published private(set) var hasMorePages = false
    private var allEntries: [ProgressPhotoEntry] = []
    private var loadedPageCount = 0

    private let fileManager = FileManager.default
    private let entriesKey = "aiqo.progressPhotos.entries"
    private let defaults = UserDefaults.standard

    private var photosDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        loadEntries()
    }

    // MARK: - Public

    /// يضيف صورة تقدم جديدة مع ملاحظة ووزن اختياري
    func addEntry(image: UIImage, weight: Double?, note: String?) {
        let id = UUID().uuidString
        let filename = "\(id).jpg"

        // حفظ الصورة بجودة عالية
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? data.write(to: fileURL)

        let entry = ProgressPhotoEntry(
            id: id,
            date: Date(),
            filename: filename,
            weightKg: weight,
            note: note
        )

        allEntries.insert(entry, at: 0)
        entries = Array(allEntries.prefix(loadedPageCount * pageSize + pageSize))
        hasMorePages = entries.count < allEntries.count
        saveEntries()
    }

    /// يحذف صورة
    func deleteEntry(_ entry: ProgressPhotoEntry) {
        let fileURL = photosDirectory.appendingPathComponent(entry.filename)
        try? fileManager.removeItem(at: fileURL)
        allEntries.removeAll { $0.id == entry.id }
        entries.removeAll { $0.id == entry.id }
        hasMorePages = entries.count < allEntries.count
        saveEntries()
    }

    /// يرجع UIImage من Entry — retained for existing SwiftUI view body callers
    func loadImage(for entry: ProgressPhotoEntry) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(entry.filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Async variant — use in .task {} modifiers to avoid main-thread disk I/O
    func loadImageAsync(for entry: ProgressPhotoEntry) async -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(entry.filename)
        return await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return UIImage(data: data)
        }.value
    }

    /// Loads the next page of entries into the published `entries` array
    func loadNextPage() {
        let nextEnd = min((loadedPageCount + 1) * pageSize, allEntries.count)
        let currentEnd = loadedPageCount * pageSize
        guard nextEnd > currentEnd else { return }
        loadedPageCount += 1
        entries = Array(allEntries.prefix(nextEnd))
        hasMorePages = nextEnd < allEntries.count
    }

    /// عدد الصور الكلي
    var totalPhotos: Int { allEntries.count }

    /// أول صورة (الأقدم)
    var firstEntry: ProgressPhotoEntry? { allEntries.last }

    /// آخر صورة (الأحدث)
    var latestEntry: ProgressPhotoEntry? { allEntries.first }

    /// تغيّر الوزن بين أول وآخر صورة
    var weightChange: Double? {
        guard let first = allEntries.last?.weightKg,
              let latest = allEntries.first?.weightKg,
              allEntries.count >= 2 else { return nil }
        return latest - first
    }

    // MARK: - Persistence

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(allEntries) else { return }
        defaults.set(data, forKey: entriesKey)
    }

    private func loadEntries() {
        guard let data = defaults.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([ProgressPhotoEntry].self, from: data) else { return }
        allEntries = decoded
        loadedPageCount = 1
        entries = Array(allEntries.prefix(pageSize))
        hasMorePages = allEntries.count > pageSize
    }
}

// MARK: - Data Model

struct ProgressPhotoEntry: Identifiable, Codable, Equatable {
    let id: String
    let date: Date
    let filename: String
    let weightKg: Double?
    let note: String?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    var daysSinceCapture: Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}
