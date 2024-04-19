@testable import MapboxNavigation
import XCTest

class DataCacheTests: XCTestCase {
    let cache: DataCache = .init()

    private func clearDisk() {
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
        self.clearDisk()
    }

    let dataKey = "dataKey"

    var exampleData: Data? {
        let bundle = Bundle.module
        do {
            return try NSData(contentsOf: bundle.url(forResource: "route", withExtension: "json")!) as Data
        } catch {
            XCTFail("Failed to create data")
            return nil
        }
    }

    private func storeDataInMemory() {
        let semaphore = DispatchSemaphore(value: 0)
        self.cache.store(self.exampleData!, forKey: self.dataKey, toDisk: false) {
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
    }

    private func storeDataOnDisk() {
        let semaphore = DispatchSemaphore(value: 0)
        self.cache.store(self.exampleData!, forKey: self.dataKey, toDisk: true) {
            semaphore.signal()
        }
        let semaphoreResult = semaphore.wait(timeout: XCTestCase.NavigationTests.timeout)
        XCTAssert(semaphoreResult == .success, "Semaphore timed out")
    }

    // MARK: Tests

    func testStoringDataInMemoryOnly() {
        self.storeDataInMemory()

        let returnedData = self.cache.data(forKey: self.dataKey)
        XCTAssertNotNil(returnedData)
    }

    func testStoringDataOnDisk() {
        self.storeDataOnDisk()

        var returnedData = self.cache.data(forKey: self.dataKey)
        XCTAssertNotNil(returnedData)

        self.cache.clearMemory()

        returnedData = self.cache.data(forKey: self.dataKey)
        XCTAssertNotNil(returnedData)
    }

    func testResettingCache() {
        self.storeDataInMemory()

        self.cache.clearMemory()

        XCTAssertNil(self.cache.data(forKey: self.dataKey))

        self.storeDataOnDisk()

        self.cache.clearMemory()
        self.clearDisk()

        XCTAssertNil(self.cache.data(forKey: self.dataKey))
    }

    func testClearingMemoryCacheOnMemoryWarning() {
        self.storeDataInMemory()

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        XCTAssertNil(self.cache.data(forKey: self.dataKey))
    }

    func testNotificationObserverDoesNotCrash() {
        var tempCache: DataCache? = DataCache()
        tempCache?.clearMemory()
        tempCache = nil

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    func testCacheKeyForKey() {
        let threeMileInstruction = "<speak><amazon:effect name=\"drc\"><prosody rate=\"1.08\">Continue on <say-as interpret-as=\"address\">I-80</say-as> East for 3 miles</prosody></amazon:effect></speak>"
        let sixMileInstruction = "<speak><amazon:effect name=\"drc\"><prosody rate=\"1.08\">Continue on <say-as interpret-as=\"address\">I-80</say-as> East for 6 miles</prosody></amazon:effect></speak>"
        XCTAssertNotEqual(self.cache.fileCache.cacheKeyForKey(threeMileInstruction), self.cache.fileCache.cacheKeyForKey(sixMileInstruction))
        XCTAssertNotEqual(self.cache.fileCache.cacheKeyForKey(""), self.cache.fileCache.cacheKeyForKey("  "))
        XCTAssertNotEqual(self.cache.fileCache.cacheKeyForKey("i"), self.cache.fileCache.cacheKeyForKey("I"))
        XCTAssertNotEqual(self.cache.fileCache.cacheKeyForKey("{"), self.cache.fileCache.cacheKeyForKey("}"))
        XCTAssertEqual(self.cache.fileCache.cacheKeyForKey("hello"), self.cache.fileCache.cacheKeyForKey("hello"))
        XCTAssertEqual(self.cache.fileCache.cacheKeyForKey("https://cool.com/neat"), self.cache.fileCache.cacheKeyForKey("https://cool.com/neat"))
        XCTAssertEqual(self.cache.fileCache.cacheKeyForKey("-"), self.cache.fileCache.cacheKeyForKey("-"))
    }

    /// NOTE: This test is disabled pending https://github.com/mapbox/mapbox-navigation-ios/issues/1468
    func x_testCacheKeyPerformance() {
        let instructionTurn = "Turn left"
        let instructionContinue = "<speak><amazon:effect name=\"drc\"><prosody rate=\"1.08\">Continue on <say-as interpret-as=\"address\">I-80</say-as> East for 3 miles</prosody></amazon:effect></speak>"
        measure {
            for _ in 0 ... 1000 {
                _ = self.cache.fileCache.cacheKeyForKey(instructionTurn)
                _ = self.cache.fileCache.cacheKeyForKey(instructionContinue)
            }
        }
    }
}
