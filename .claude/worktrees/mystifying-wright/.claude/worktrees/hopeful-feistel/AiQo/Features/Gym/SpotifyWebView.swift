import SwiftUI
import UIKit
import WebKit

struct SpotifyWebView: UIViewRepresentable {
    let playlistID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        if #available(iOS 15.0, *) {
            webView.underPageBackgroundColor = .clear
        }

        loadPlaylistIfNeeded(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        loadPlaylistIfNeeded(into: uiView)
    }

    private func loadPlaylistIfNeeded(into webView: WKWebView) {
        guard let url = URL(
            string: "https://open.spotify.com/embed/playlist/\(playlistID)?utm_source=generator&theme=0"
        ) else {
            return
        }

        guard webView.url?.absoluteString != url.absoluteString else { return }
        webView.load(URLRequest(url: url))
    }
}

struct SpotifyVibesLibrarySheet: View {
    let playlistID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AiQo Vibes / سبوتيفاي")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.88))

            SpotifyWebView(playlistID: playlistID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    SpotifyVibesLibrarySheet(playlistID: "37i9dQZF1DX4sWSpwq3LiO")
        .presentationBackground(.ultraThinMaterial)
}
