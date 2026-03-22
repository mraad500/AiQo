import SwiftUI
import UIKit

struct SpotifyVibeCard: View {
    enum Presentation {
        case standalone
        case embedded
    }

    let recommendation: SpotifyRecommendation
    var presentation: Presentation = .standalone

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            summary
            footer
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if presentation == .standalone {
                cardBackground
            }
        }
        .overlay {
            if presentation == .standalone {
                cardStroke
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            openRecommendation()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Open \(recommendation.vibeName) in Spotify")
    }
}

private extension SpotifyVibeCard {
    var contentPadding: CGFloat {
        presentation == .standalone ? 18 : 0
    }

    var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "BCE2C6"),
                                Color(hex: "E8F3DE")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text("vibe.djPick".localized)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "BCE2C6").opacity(0.92))

                Text(recommendation.vibeName)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(destinationLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.76))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
        }
    }

    var summary: some View {
        Text(recommendation.description)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
    }

    var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 13, weight: .semibold))

                    Text("vibe.openSpotify".localized)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.black.opacity(0.78))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(hex: "BCE2C6"))
                )

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 13, weight: .semibold))

                    Text("vibe.openSpotify".localized)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.black.opacity(0.78))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(hex: "BCE2C6"))
                )

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))
            }
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color(hex: "BCE2C6").opacity(0.22),
                        Color.white.opacity(0.08),
                        Color(hex: "F0E1C2").opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    var cardStroke: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(Color.white.opacity(0.16), lineWidth: 1)
    }

    var destinationLabel: String {
        let segments = recommendation.spotifyURI.split(separator: ":", omittingEmptySubsequences: true)
        guard segments.count > 1 else { return "Spotify" }

        switch segments[1] {
        case "search":
            return "Search"
        case "playlist":
            return "Playlist"
        case "album":
            return "Album"
        case "artist":
            return "Artist"
        default:
            return "Spotify"
        }
    }

    func openRecommendation() {
        guard let appURL = spotifyAppURL else {
            openFallbackURL()
            return
        }

        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            openFallbackURL()
        }
    }

    var spotifyAppURL: URL? {
        makeURL(from: recommendation.spotifyURI)
    }

    var spotifyWebURL: URL? {
        let trimmedURI = recommendation.spotifyURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURI.hasPrefix("spotify:") else {
            return makeURL(from: trimmedURI)
        }

        let pathSegments = trimmedURI
            .split(separator: ":", omittingEmptySubsequences: false)
            .dropFirst()
            .map(String.init)
            .map { segment in
                segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? segment
            }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "open.spotify.com"
        components.percentEncodedPath = "/" + pathSegments.joined(separator: "/")
        return components.url
    }

    func openFallbackURL() {
        guard let fallbackURL = spotifyWebURL else { return }
        UIApplication.shared.open(fallbackURL)
    }

    func makeURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        if let url = URL(string: trimmedValue) {
            return url
        }

        guard let encoded = trimmedValue.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
            return nil
        }

        return URL(string: encoded)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        SpotifyVibeCard(
            recommendation: SpotifyRecommendation(
                vibeName: "Golden Focus",
                description: "A steady mint-toned focus lane for deep work with soft forward motion.",
                spotifyURI: "spotify:search:deep+focus+mix"
            )
        )
        .padding()
    }
}
