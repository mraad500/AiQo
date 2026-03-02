import SwiftUI
internal import Combine
import UIKit
import ImageIO

private enum CachedAsyncImageError: Error {
    case invalidResponse
    case decodingFailed
}

private final class MatchImageCache {
    static let shared = MatchImageCache()

    private let storage = NSCache<NSURL, UIImage>()

    private init() {
        storage.countLimit = 256
        storage.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        storage.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL, cost: Int) {
        storage.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

enum MatchImagePipeline {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            diskPath: "AiQoMatchImages"
        )
        return URLSession(configuration: configuration)
    }()

    private static let decodingQueue = DispatchQueue(
        label: "AiQo.MatchImagePipeline.decoding",
        qos: .userInitiated,
        attributes: .concurrent
    )

    static func prefetch(urls: [URL]) async {
        let uniqueURLs = Array(Set(urls))
        await withTaskGroup(of: Void.self) { group in
            for url in uniqueURLs {
                group.addTask(priority: .utility) {
                    _ = try? await image(for: url)
                }
            }
        }
    }

    static func image(for url: URL) async throws -> UIImage {
        if let cached = MatchImageCache.shared.image(for: url) {
            return cached
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CachedAsyncImageError.invalidResponse
        }

        let decodedImage = try await decodeImage(from: data)
        MatchImageCache.shared.insert(decodedImage, for: url, cost: data.count)
        return decodedImage
    }

    private static func decodeImage(from data: Data) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            decodingQueue.async {
                let options: [CFString: Any] = [
                    kCGImageSourceShouldCache: true,
                    kCGImageSourceShouldCacheImmediately: true
                ]

                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
                    continuation.resume(throwing: CachedAsyncImageError.decodingFailed)
                    return
                }

                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }
}

@MainActor
private final class CachedImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private var lastURL: URL?

    func load(from url: URL?) async {
        guard lastURL != url else { return }
        lastURL = url

        guard let url else {
            image = nil
            return
        }

        if let cached = MatchImageCache.shared.image(for: url) {
            image = cached
            return
        }

        do {
            image = try await MatchImagePipeline.image(for: url)
        } catch {
            image = nil
        }
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = CachedImageLoader()

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loader.load(from: url)
        }
    }
}
