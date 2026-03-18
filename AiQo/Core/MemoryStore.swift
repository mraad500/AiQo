import Foundation
import SwiftData
import os.log

/// مدير ذاكرة الكابتن حمّودي — يحفظ ويسترجع الذكريات عبر الجلسات
@MainActor
@Observable
final class MemoryStore {
    static let shared = MemoryStore()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AiQo", category: "MemoryStore")
    private var container: ModelContainer?
    private var context: ModelContext?
    private static let maxMemories = 200

    /// هل ذاكرة الكابتن مفعّلة
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "captain_memory_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "captain_memory_enabled") }
    }

    private init() {
        // isEnabled defaults to true on first launch
        if UserDefaults.standard.object(forKey: "captain_memory_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "captain_memory_enabled")
        }
    }

    /// ربط الـ ModelContainer — يُستدعى من نقطة الدخول
    func configure(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    // MARK: - CRUD

    /// حفظ أو تحديث ذاكرة
    func set(_ key: String, value: String, category: String, source: String, confidence: Double = 0.7) {
        guard isEnabled, let context else { return }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.key == key }
            )
            let existing = try context.fetch(descriptor)

            if let memory = existing.first {
                memory.value = value
                memory.updatedAt = Date()
                memory.confidence = min(memory.confidence + 0.05, 1.0)
                if memory.source != "user_explicit" || source == "user_explicit" {
                    memory.source = source
                }
            } else {
                // تحقق من الحد الأقصى
                let countDescriptor = FetchDescriptor<CaptainMemory>()
                let count = (try? context.fetchCount(countDescriptor)) ?? 0
                if count >= Self.maxMemories {
                    removeLowestConfidence()
                }

                let memory = CaptainMemory(
                    key: key,
                    value: value,
                    category: category,
                    source: source,
                    confidence: confidence
                )
                context.insert(memory)
            }

            try context.save()
        } catch {
            logger.error("memory_store_set_error key=\(key) error=\(error.localizedDescription)")
        }
    }

    /// استرجاع قيمة بالمفتاح
    func get(_ key: String) -> String? {
        guard let context else { return nil }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.key == key }
            )
            return try context.fetch(descriptor).first?.value
        } catch {
            logger.error("memory_store_get_error key=\(key) error=\(error.localizedDescription)")
            return nil
        }
    }

    /// استرجاع كل الذكريات بتصنيف معين
    func getByCategory(_ category: String) -> [CaptainMemory] {
        guard let context else { return [] }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.category == category },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            logger.error("memory_store_category_error category=\(category) error=\(error.localizedDescription)")
            return []
        }
    }

    /// كل الذكريات مرتبة بالتصنيف
    func allMemories() -> [CaptainMemory] {
        guard let context else { return [] }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                sortBy: [SortDescriptor(\.category), SortDescriptor(\.updatedAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            logger.error("memory_store_all_error error=\(error.localizedDescription)")
            return []
        }
    }

    /// بناء سياق الذكريات للـ system prompt
    func buildPromptContext(maxTokens: Int = 800) -> String {
        guard isEnabled, let context else { return "" }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            var memories = try context.fetch(descriptor)

            // رتّب بالأولوية: confidence * recency_weight
            let now = Date()
            memories.sort { a, b in
                priorityScore(for: a, now: now) > priorityScore(for: b, now: now)
            }

            var lines: [String] = []
            var estimatedTokens = 0

            // دايماً ضمّن معلومات المشروع النشط أولاً
            let projectMemories = memories.filter { $0.category == "active_record_project" }
            let otherMemories = memories.filter { $0.category != "active_record_project" }

            for memory in projectMemories + otherMemories {
                let line = "- \(memory.key): \(memory.value)"
                let lineTokens = line.count / 4
                if estimatedTokens + lineTokens > maxTokens { break }

                lines.append(line)
                estimatedTokens += lineTokens

                memory.accessCount += 1
            }

            try context.save()
            return lines.joined(separator: "\n")
        } catch {
            logger.error("memory_store_prompt_error error=\(error.localizedDescription)")
            return ""
        }
    }

    /// تنظيف الذكريات القديمة واللي confidence قليل
    func removeStale(olderThan days: Int = 90, belowConfidence: Double = 0.3) {
        guard let context else { return }

        do {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate {
                    $0.updatedAt < cutoff && $0.confidence < belowConfidence && $0.category != "active_record_project"
                }
            )
            let stale = try context.fetch(descriptor)
            for memory in stale {
                context.delete(memory)
            }
            try context.save()
            logger.info("memory_store_cleanup removed=\(stale.count)")
        } catch {
            logger.error("memory_store_cleanup_error error=\(error.localizedDescription)")
        }
    }

    /// حذف ذاكرة بالمفتاح
    func remove(_ key: String) {
        guard let context else { return }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.key == key }
            )
            let results = try context.fetch(descriptor)
            for memory in results {
                context.delete(memory)
            }
            try context.save()
        } catch {
            logger.error("memory_store_remove_error key=\(key) error=\(error.localizedDescription)")
        }
    }

    /// مسح كل الذاكرة
    func clearAll() {
        guard let context else { return }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>()
            let all = try context.fetch(descriptor)
            for memory in all {
                context.delete(memory)
            }
            try context.save()
            logger.info("memory_store_clear_all")
        } catch {
            logger.error("memory_store_clear_error error=\(error.localizedDescription)")
        }
    }

    /// ملخص للـ debug
    func summary() -> String {
        guard let context else { return "MemoryStore: not configured" }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>()
            let count = try context.fetchCount(descriptor)
            return "MemoryStore: \(count) memories, enabled=\(isEnabled)"
        } catch {
            return "MemoryStore: error reading count"
        }
    }

    // MARK: - Private

    private func priorityScore(for memory: CaptainMemory, now: Date) -> Double {
        let hoursSinceUpdate = now.timeIntervalSince(memory.updatedAt) / 3600
        let recencyWeight: Double
        if hoursSinceUpdate < 24 {
            recencyWeight = 1.0
        } else if hoursSinceUpdate < 168 { // أسبوع
            recencyWeight = 0.8
        } else if hoursSinceUpdate < 720 { // شهر
            recencyWeight = 0.6
        } else {
            recencyWeight = 0.4
        }
        return memory.confidence * recencyWeight
    }

    private func removeLowestConfidence() {
        guard let context else { return }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.category != "active_record_project" },
                sortBy: [SortDescriptor(\.confidence)]
            )
            let all = try context.fetch(descriptor)
            if let lowest = all.first {
                context.delete(lowest)
            }
        } catch {
            logger.error("memory_store_remove_lowest_error error=\(error.localizedDescription)")
        }
    }
}
