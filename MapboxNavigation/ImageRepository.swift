import UIKit

class ImageRepository {
    public var sessionConfiguration: URLSessionConfiguration = .default {
        didSet {
            imageDownloader = ImageDownloader(sessionConfiguration: sessionConfiguration)
        }
    }

    public static let shared = ImageRepository()

    let imageCache: BimodalImageCache
    private(set) var imageDownloader: ReentrantImageDownloader

    var useDiskCache: Bool

    required init(withDownloader downloader: ReentrantImageDownloader = ImageDownloader(), cache: BimodalImageCache = ImageCache(), useDisk: Bool = true) {
        imageDownloader = downloader
        imageCache = cache
        useDiskCache = useDisk
    }

    func resetImageCache(_ completion: CompletionHandler?) {
        imageCache.clearMemory()
        imageCache.clearDisk(completion: completion)
    }

    func storeImage(_ image: UIImage, forKey key: String, toDisk: Bool = true) {
        imageCache.store(image, forKey: key, toDisk: toDisk, completion: nil)
    }

    func cachedImageForKey(_ key: String) -> UIImage? {
        imageCache.image(forKey: key)
    }

    func imageWithURL(_ imageURL: URL, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        if let cachedImage = cachedImageForKey(cacheKey) {
            completion(cachedImage)
            return
        }

        _ = imageDownloader.downloadImage(with: imageURL, completion: { [weak self] image, _, error in
            guard let strongSelf = self, let image else {
                completion(nil)
                return
            }

            guard error == nil else {
                completion(image)
                return
            }

            strongSelf.imageCache.store(image, forKey: cacheKey, toDisk: strongSelf.useDiskCache, completion: {
                completion(image)
            })
        })
    }

    func disableDiskCache() {
        useDiskCache = false
    }
}
