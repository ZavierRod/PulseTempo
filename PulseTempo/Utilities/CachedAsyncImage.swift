//
//  CachedAsyncImage.swift
//  PulseTempo
//

import SwiftUI

/// In-memory image cache backed by NSCache.
/// Automatically evicts under memory pressure.
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

/// Drop-in replacement for `AsyncImage` that checks an in-memory cache first.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

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
        if let image = loadedImage {
            content(Image(uiImage: image))
        } else if loadFailed {
            placeholder()
        } else {
            placeholder()
                .onAppear { loadImage() }
        }
    }

    private func loadImage() {
        guard let url else {
            loadFailed = true
            return
        }

        if let cached = ImageCache.shared.image(for: url) {
            loadedImage = cached
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data, error == nil, let uiImage = UIImage(data: data) else {
                DispatchQueue.main.async { loadFailed = true }
                return
            }
            ImageCache.shared.setImage(uiImage, for: url)
            DispatchQueue.main.async { loadedImage = uiImage }
        }.resume()
    }
}
