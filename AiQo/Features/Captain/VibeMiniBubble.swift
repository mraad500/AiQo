// ===============================================
// File: VibeMiniBubble.swift
// Phase 5 — Captain Hamoudi Brain V2
// Compact Spotify recommendation card rendered
// below Captain chat messages.
// ===============================================

import SwiftUI

/// Compact card for Spotify recommendations attached to Captain messages.
struct VibeMiniBubble: View {
    let vibeName: String
    let description: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AiQoColors.mint)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(vibeName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text(description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AiQoColors.mint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AiQoColors.mint.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AiQoColors.mint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
