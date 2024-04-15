@testable import MapboxNavigation
import XCTest

class ImageRepositoryTests: XCTestCase {
    lazy var repository: ImageRepository = {
        let repo = ImageRepository.shared
        let config = URLSessionConfiguration.default
        config.protocolClasses = [ImageLoadingURLProtocolSpy.self]
        repo.sessionConfiguration = config

        return repo
    }()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        ImageLoadingURLProtocolSpy.reset()

        let semaphore = DispatchSemaphore(value: 0)
        self.repository.resetImageCache {
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
    }

    override func tearDown() {
        super.tearDown()
    }

    func test_imageWithURL_downloadsImageWhenNotCached() {
        let imageName = "1.png"
        let fakeURL = URL(string: "http://an.image.url/\(imageName)")!

        ImageLoadingURLProtocolSpy.registerData(ShieldImage.i280.image.pngData()!, forURL: fakeURL)
        XCTAssertNil(self.repository.cachedImageForKey(imageName))

        var imageReturned: UIImage? = nil
        let semaphore = DispatchSemaphore(value: 0)

        self.repository.imageWithURL(fakeURL, cacheKey: imageName) { image in
            imageReturned = image
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
        
        XCTAssertNotNil(imageReturned)
        // round-trip through UIImagePNGRepresentation results in changes in data due to metadata stripping, thus direct image comparison is not always possible.
        XCTAssertTrue((imageReturned?.isKind(of: UIImage.self))!)
    }

    func test_imageWithURL_prefersCachedImageWhenAvailable() {
        let imageName = "1.png"
        let fakeURL = URL(string: "http://an.image.url/\(imageName)")!

        self.repository.storeImage(ShieldImage.i280.image, forKey: imageName, toDisk: false)

        var imageReturned: UIImage? = nil
        let semaphore = DispatchSemaphore(value: 0)

        self.repository.imageWithURL(fakeURL, cacheKey: imageName) { image in
            imageReturned = image
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
        
        XCTAssertNil(ImageLoadingURLProtocolSpy.pastRequestForURL(fakeURL))
        XCTAssertNotNil(imageReturned)
    }
}
