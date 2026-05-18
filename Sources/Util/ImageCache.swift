import UIKit

/// Decoded-image cache + sized URLCache for hub media URLs.
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.totalCostLimit = 64 * 1024 * 1024
        c.countLimit = 512
        return c
    }()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    static func configureURLCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
    }
}
