import SwiftUI
import WebKit

// ✅ كارت اليوتيوب (النسخة النهائية مع حل User Agent)
struct YouTubeCardView: View {
    var onClose: () -> Void
    
    // 👇 فيديو تجريبي مضمون (Apple SwiftUI Intro)
    // جرّب هذا الفيديو أولاً، إذا عمل، يمكنك استبداله بالفيديو الخاص بك
    let videoID = "m44z-J1bB3A"
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // المتصفح
            YouTubeWebView(videoID: videoID)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.72, green: 0.91, blue: 0.83), lineWidth: 2) // Mint
                )
                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 5)
            
            // زر الإغلاق (X)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.6).clipShape(Circle()))
            }
            .padding(10)
        }
        .padding(.horizontal, 20)
    }
}

// ✅ المتصفح مع تحايل "User Agent" لخداع يوتيوب
struct YouTubeWebView: UIViewRepresentable {
    let videoID: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // السماح بالتشغيل داخل التطبيق (بدون ملء الشاشة إجبارياً)
        config.allowsInlineMediaPlayback = true
        
        // تفعيل تشغيل الفيديو تلقائياً (اختياري، يقلل من تعقيد التشغيل)
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // 🔥 الحل الجذري (1): تغيير هوية المتصفح
        // نجعل التطبيق يدعي أنه iPhone Safari عادي ليتخطى حظر التطبيقات
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 🔥 الحل (2): HTML نظيف جداً
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
            <style>
                body { margin: 0; padding: 0; background-color: black; }
                .video-container { position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; }
                .video-container iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe 
                    src="https://www.youtube.com/embed/\(videoID)?playsinline=1&autoplay=1&controls=1&fs=0&rel=0&modestbranding=1" 
                    frameborder="0" 
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                    allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """
        
        // تحميل الـ HTML مع "خداع" المصدر (Origin)
        uiView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
    }
}
