import UIKit

@objc(MBDataCache)
public class DataCache: NSObject, BimodalDataCache {
    let memoryCache: NSCache<NSString, NSData>
    let fileCache = FileCache()

    override public init() {
        self.memoryCache = NSCache<NSString, NSData>()
        self.memoryCache.name = "In-Memory Data Cache"

        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(DataCache.clearMemory), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    // MARK: Data cache

    /*
      Stores data in the cache for the given key. If `toDisk` is set to `true`, the completion handler is called following writing the data to disk, otherwise it is called immediately upon storing the data in the memory cache.
     */
    public func store(_ data: Data, forKey key: String, toDisk: Bool, completion: CompletionHandler?) {
        self.storeDataInMemoryCache(data, forKey: key)

        if toDisk {
            self.fileCache.store(data, forKey: key, completion: completion)
        } else {
            completion?()
        }
    }

    /*
     Returns data from the cache for the given key, if any. The memory cache is consulted first, followed by the disk cache. If data is found on disk which isn't in memory, it is added to the memory cache.
     */
    public func data(forKey key: String?) -> Data? {
        guard let key else {
            return nil
        }

        if let data = dataFromMemoryCache(forKey: key) {
            return data
        }

        if let data = fileCache.dataFromFileCache(forKey: key) {
            self.storeDataInMemoryCache(data, forKey: key)
            return data
        }

        return nil
    }

    /*
     Clears out the memory cache.
     */
    public func clearMemory() {
        self.memoryCache.removeAllObjects()
    }

    /*
     Clears the disk cache and calls the completion handler when finished.
     */
    public func clearDisk(completion: CompletionHandler?) {
        self.fileCache.clearDisk(completion: completion)
    }

    private func storeDataInMemoryCache(_ data: Data, forKey key: String) {
        self.memoryCache.setObject(data as NSData, forKey: key as NSString)
    }

    private func dataFromMemoryCache(forKey key: String) -> Data? {
        if let data = memoryCache.object(forKey: key as NSString) {
            return data as Data
        }
        return nil
    }
}
