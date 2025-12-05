//
//  CachedAsyncImage.swift
//  app ch3
//
//  Cached async image for better performance
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
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
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cachedImage
            return
        }
        
        // Load from network
        isLoading = true
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        ImageCache.shared.set(uiImage, forKey: url.absoluteString)
                        self.image = uiImage
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// Simple image cache using NSCache
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // Max 50MB
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}
