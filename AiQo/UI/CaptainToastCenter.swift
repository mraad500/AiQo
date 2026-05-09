import Combine
import Foundation
import SwiftUI

/// Lightweight global broadcast point for one-line Captain messages that should
/// slide down from the top of the app while it is foregrounded.
///
/// Used by `WorkoutAnalysisAnnouncer` to surface the post-workout analysis when
/// the app is active; the same message is also handed to `NotificationBrain`
/// so iOS can deliver it as a notification when the app is backgrounded.
struct CaptainToast: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String
    let accentSymbolName: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        message: String,
        accentSymbolName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.accentSymbolName = accentSymbolName
        self.createdAt = createdAt
    }
}

@MainActor
final class CaptainToastCenter: ObservableObject {
    static let shared = CaptainToastCenter()

    @Published private(set) var current: CaptainToast?

    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// Show a toast and auto-dismiss after `autoDismissAfter` seconds.
    /// Replacing an in-flight toast is fine — the dismissal task is cancelled.
    func present(_ toast: CaptainToast, autoDismissAfter: TimeInterval = 5.5) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            current = toast
        }
        HapticEngine.light()
        let token = toast.id
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.5, autoDismissAfter) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.current?.id == token else { return }
                self.dismiss()
            }
        }
    }

    func dismiss() {
        guard current != nil else { return }
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeOut(duration: 0.28)) {
            current = nil
        }
    }
}
