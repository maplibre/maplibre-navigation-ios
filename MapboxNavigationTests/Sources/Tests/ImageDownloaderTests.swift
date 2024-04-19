@testable import MapboxNavigation
import XCTest

class ImageDownloaderTests: XCTestCase {
    lazy var sessionConfig: URLSessionConfiguration = {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [ImageLoadingURLProtocolSpy.self]
        return config
    }()

    var downloader: ReentrantImageDownloader?

    let imageURL = URL(string: "https://zombo.com/lulz/selfie.png")!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        ImageLoadingURLProtocolSpy.reset()

        let imageData = ShieldImage.i280.image.pngData()!
        ImageLoadingURLProtocolSpy.registerData(imageData, forURL: self.imageURL)

        self.downloader = ImageDownloader(sessionConfiguration: self.sessionConfig)
    }

    override func tearDown() {
        self.downloader = nil

        super.tearDown()
    }

    func testDownloadingAnImage() {
        guard let downloader else {
            XCTFail()
            return
        }
        var imageReturned: UIImage?
        var dataReturned: Data?
        var errorReturned: Error?
        let semaphore = DispatchSemaphore(value: 0)

        downloader.downloadImage(with: self.imageURL) { image, data, error in
            imageReturned = image
            dataReturned = data
            errorReturned = error
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")

        // The ImageDownloader is meant to be used with an external caching mechanism
        let request = ImageLoadingURLProtocolSpy.pastRequestForURL(self.imageURL)!
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringCacheData)

        XCTAssertNotNil(imageReturned)
        XCTAssertTrue(imageReturned!.isKind(of: UIImage.self))
        XCTAssertNotNil(dataReturned)
        XCTAssertNil(errorReturned)
    }

    func testDownloadingImageWhileAlreadyInProgressAddsCallbacksWithoutAddingAnotherRequest() {
        guard let downloader else {
            XCTFail()
            return
        }
        var firstCallbackCalled = false
        var secondCallbackCalled = false
        var operation: ImageDownload

        // URL loading is delayed in order to simulate conditions under which multiple requests for the same asset would be made
        ImageLoadingURLProtocolSpy.delayImageLoading()

        downloader.downloadImage(with: self.imageURL) { _, _, _ in
            firstCallbackCalled = true
        }
        operation = downloader.activeOperation(with: self.imageURL)!

        downloader.downloadImage(with: self.imageURL) { _, _, _ in
            secondCallbackCalled = true
        }

        ImageLoadingURLProtocolSpy.resumeImageLoading()

        XCTAssertTrue(operation === downloader.activeOperation(with: self.imageURL)!,
                      "Expected \(String(describing: operation)) to be identical to \(String(describing: downloader.activeOperation(with: self.imageURL)))")

        var spinCount = 0

        runUntil {
            spinCount += 1
            return operation.isFinished
        }

        print("Succeeded after evaluating condition \(spinCount) times.")

        XCTAssertTrue(firstCallbackCalled)
        XCTAssertTrue(secondCallbackCalled)
    }

    func testDownloadingImageAgainAfterFirstDownloadCompletes() {
        guard let downloader else {
            XCTFail()
            return
        }
        var callbackCalled = false
        var spinCount = 0

        downloader.downloadImage(with: self.imageURL) { _, _, _ in
            callbackCalled = true
        }
        var operation = downloader.activeOperation(with: self.imageURL)!

        runUntil {
            spinCount += 1
            return operation.isFinished
        }

        print("Succeeded after evaluating first condition \(spinCount) times.")
        XCTAssertTrue(callbackCalled)

        callbackCalled = false
        spinCount = 0

        downloader.downloadImage(with: self.imageURL) { _, _, _ in
            callbackCalled = true
        }
        operation = downloader.activeOperation(with: self.imageURL)!

        runUntil {
            spinCount += 1
            return operation.isFinished
        }

        print("Succeeded after evaluating second condition \(spinCount) times.")
        XCTAssertTrue(callbackCalled)
    }
}
