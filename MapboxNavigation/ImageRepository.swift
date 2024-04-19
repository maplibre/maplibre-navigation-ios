import UIKit

class ImageRepository {
    public var sessionConfiguration: URLSessionConfiguration = .default {
        didSet {
            self.imageDownloader = ImageDownloader(sessionConfiguration: self.sessionConfiguration)
        }
    }

    public static let shared = ImageRepository()

    let imageCache: BimodalImageCache
    private(set) var imageDownloader: ReentrantImageDownloader

    var useDiskCache: Bool

    required init(withDownloader downloader: ReentrantImageDownloader = ImageDownloader(), cache: BimodalImageCache = ImageCache(), useDisk: Bool = true) {
        self.imageDownloader = downloader
        self.imageCache = cache
        self.useDiskCache = useDisk
    }

    func resetImageCache(_ completion: CompletionHandler?) {
        self.imageCache.clearMemory()
        self.imageCache.clearDisk(completion: completion)
    }

    func storeImage(_ image: UIImage, forKey key: String, toDisk: Bool = true) {
        self.imageCache.store(image, forKey: key, toDisk: toDisk, completion: nil)
    }

    func cachedImageForKey(_ key: String) -> UIImage? {
        self.imageCache.image(forKey: key)
    }

    func imageWithURL(_ imageURL: URL, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        if let cachedImage = cachedImageForKey(cacheKey) {
            completion(cachedImage)
            return
        }

        _ = self.imageDownloader.downloadImage(with: imageURL, completion: { [weak self] image, _, error in
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
        self.useDiskCache = false
    }
}
