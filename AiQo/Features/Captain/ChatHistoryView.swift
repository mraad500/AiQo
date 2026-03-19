import SwiftUI

// MARK: - Chat History View

/// شاشة المحادثات السابقة — تعرض قائمة الجلسات القديمة مع preview وتاريخ
struct ChatHistoryView: View {
    @EnvironmentObject private var viewModel: CaptainViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    @State private var sessions: [ChatSession] = []

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("المحادثات")
            .navigationBarTitleDisplayMode(.inline)
            .fontDesign(.rounded)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.startNewChat()
                        dismiss()
                    } label: {
                        Label("محادثة جديدة", systemImage: "plus.message")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.subtext)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(theme.fieldBackground))
                            .overlay(Circle().stroke(theme.border, lineWidth: 0.7))
                    }
                }
            }
            .onAppear {
                sessions = MemoryStore.shared.fetchSessions()
            }
        }
    }
}

// MARK: - Subviews

private extension ChatHistoryView {
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44, weight: .light, design: .rounded))
                .foregroundStyle(theme.subtext.opacity(0.4))

            Text("ما عندك محادثات سابقة")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(theme.subtext)
        }
    }

    var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    func sessionRow(_ session: ChatSession) -> some View {
        Button {
            viewModel.loadSession(session)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                // أيقونة المحادثة
                ZStack {
                    Circle()
                        .fill(theme.spatialMint.opacity(0.15))
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.spatialMint)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.preview.isEmpty ? "محادثة" : session.preview)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.text)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(formattedDate(session.timestamp))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.subtext)

                        Text("·")
                            .foregroundColor(theme.subtext.opacity(0.5))

                        Text("\(session.messageCount) رسالة")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.subtext)
                    }
                }

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.subtext.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.border, lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(.plain)
        // تمييز الجلسة الحالية
        .opacity(session.id == viewModel.currentSessionID ? 0.5 : 1)
    }

    func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "اليوم"
        } else if calendar.isDateInYesterday(date) {
            return "أمس"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ar")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}
