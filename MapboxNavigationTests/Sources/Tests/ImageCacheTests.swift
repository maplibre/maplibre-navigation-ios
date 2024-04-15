@testable import MapboxNavigation
import XCTest

class ImageCacheTests: XCTestCase {
    let cache: ImageCache = .init()
    let asyncTimeout: TimeInterval = 10.0

    private func clearDiskCache() {
        let semaphore = DispatchSemaphore(value: 0)
        self.cache.clearDisk {
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        self.cache.clearMemory()
        self.clearDiskCache()
    }

    let imageKey = "imageKey"

    private func storeImageInMemory() {
        let semaphore = DispatchSemaphore(value: 0)
        self.cache.store(ShieldImage.i280.image, forKey: self.imageKey, toDisk: false) {
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
    }

    private func storeImageOnDisk() {
        let semaphore = DispatchSemaphore(value: 0)
        self.cache.store(ShieldImage.i280.image, forKey: self.imageKey, toDisk: true) {
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
    }

    // MARK: Tests

    func testUsingURLStringAsCacheKey() {
        let cacheKeyURLString = "https://zombo.com/lulz/shieldKey.xyz"
        let expectation = expectation(description: "Storing image in disk cache")
        self.cache.store(ShieldImage.i280.image, forKey: cacheKeyURLString, toDisk: true) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: self.asyncTimeout)

        let returnedImage = self.cache.image(forKey: cacheKeyURLString)
        XCTAssertTrue((returnedImage?.isKind(of: UIImage.self))!)
    }

    func testUsingPathStringAsCacheKey() {
        let cacheKeyURLString = "/path/to/something.xyz"
        let expectation = expectation(description: "Storing image in disk cache")
        self.cache.store(ShieldImage.i280.image, forKey: cacheKeyURLString, toDisk: true) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: self.asyncTimeout)

        let returnedImage = self.cache.image(forKey: cacheKeyURLString)
        XCTAssertTrue((returnedImage?.isKind(of: UIImage.self))!)
    }

    func testStoringImageInMemoryOnly() {
        self.storeImageInMemory()

        let returnedImage = self.cache.image(forKey: self.imageKey)
        XCTAssertTrue((returnedImage?.isKind(of: UIImage.self))!)
    }

    func testStoringImageOnDisk() {
        self.storeImageOnDisk()

        var returnedImage = self.cache.image(forKey: self.imageKey)
        XCTAssertTrue((returnedImage?.isKind(of: UIImage.self))!)

        self.cache.clearMemory()

        returnedImage = self.cache.image(forKey: self.imageKey)
        XCTAssertNotNil(returnedImage)
        XCTAssertTrue((returnedImage?.isKind(of: UIImage.self))!)
    }

    func testResettingCache() {
        self.storeImageInMemory()

        self.cache.clearMemory()

        XCTAssertNil(self.cache.image(forKey: self.imageKey))

        self.storeImageOnDisk()

        self.cache.clearMemory()
        self.clearDiskCache()

        XCTAssertNil(self.cache.image(forKey: self.imageKey))
    }

    func testClearingMemoryCacheOnMemoryWarning() {
        self.storeImageInMemory()
        
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        XCTAssertNil(self.cache.image(forKey: self.imageKey))
    }

    func testJPEGSupport() {
        let imageJPEGData = ShieldImage.i280.image.jpegData(compressionQuality: 9.0)!
        let image = UIImage(data: imageJPEGData)!

        let expectation = expectation(description: "Storing image in disk cache")
        self.cache.store(image, forKey: "JPEG Test", toDisk: true) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: self.asyncTimeout)

        let retrievedImage = self.cache.image(forKey: "JPEG Test")!
        XCTAssertTrue(retrievedImage.isKind(of: UIImage.self))
    }

    func testNotificationObserverDoesNotCrash() {
        var tempCache: ImageCache? = ImageCache()
        tempCache?.clearMemory()
        tempCache = nil

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
}
