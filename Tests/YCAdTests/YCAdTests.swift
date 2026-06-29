import XCTest
@testable import YCAd

final class YCAdTests: XCTestCase {

    // MARK: - YCAdType

    func testYCAdType_allCasesContains5Types() {
        XCTAssertEqual(YCAdType.allCases.count, 5)
        XCTAssertTrue(YCAdType.allCases.contains(.banner))
        XCTAssertTrue(YCAdType.allCases.contains(.interstitial))
        XCTAssertTrue(YCAdType.allCases.contains(.rewarded))
        XCTAssertTrue(YCAdType.allCases.contains(.appOpen))
        XCTAssertTrue(YCAdType.allCases.contains(.native))
    }

    func testYCAdType_displayName() {
        XCTAssertFalse(YCAdType.banner.displayName.isEmpty)
        XCTAssertFalse(YCAdType.interstitial.displayName.isEmpty)
        XCTAssertFalse(YCAdType.rewarded.displayName.isEmpty)
        XCTAssertFalse(YCAdType.appOpen.displayName.isEmpty)
        XCTAssertFalse(YCAdType.native.displayName.isEmpty)
    }

    // MARK: - YCAdLogLevel

    @MainActor
    func testYCAdLogLevel_ordering() {
        XCTAssertLessThan(YCAdLogLevel.debug, YCAdLogLevel.info)
        XCTAssertLessThan(YCAdLogLevel.info, YCAdLogLevel.warning)
        XCTAssertLessThan(YCAdLogLevel.warning, YCAdLogLevel.error)
        XCTAssertLessThan(YCAdLogLevel.error, YCAdLogLevel.none)
    }

    @MainActor
    func testYCAdLogger_levelFiltering() async {
        let logger = YCAdLogger.shared
        logger.level = .warning
        logger.clear()
        logger.log(.debug, "debug-msg")
        logger.log(.info, "info-msg")
        logger.log(.warning, "warn-msg")
        logger.log(.error, "error-msg")
        // 低于 warning 的应被过滤
        XCTAssertEqual(logger.entries.count, 2)
        XCTAssertEqual(logger.entries[0].level, .warning)
        XCTAssertEqual(logger.entries[1].level, .error)
        // 恢复默认
        logger.level = .defaultLevel
    }

    @MainActor
    func testYCAdLogger_noneLevelDropsAll() {
        let logger = YCAdLogger.shared
        logger.level = .none
        logger.clear()
        logger.log(.error, "should-be-dropped")
        XCTAssertEqual(logger.entries.count, 0)
        logger.level = .defaultLevel
    }

    @MainActor
    func testYCAdLogger_clear() {
        let logger = YCAdLogger.shared
        logger.level = .debug
        logger.log(.debug, "a")
        logger.log(.info, "b")
        XCTAssertGreaterThan(logger.entries.count, 0)
        logger.clear()
        XCTAssertEqual(logger.entries.count, 0)
        logger.level = .defaultLevel
    }

    @MainActor
    func testYCAdLogger_maxBufferedEntries() {
        let logger = YCAdLogger.shared
        let originalMax = logger.maxBufferedEntries
        let originalLevel = logger.level
        defer {
            logger.maxBufferedEntries = originalMax
            logger.level = originalLevel
        }
        logger.maxBufferedEntries = 3
        logger.level = .debug
        logger.clear()
        logger.log(.debug, "1")
        logger.log(.debug, "2")
        logger.log(.debug, "3")
        logger.log(.debug, "4")
        logger.log(.debug, "5")
        XCTAssertEqual(logger.entries.count, 3)
        XCTAssertEqual(logger.entries[0].message, "3")
        XCTAssertEqual(logger.entries[2].message, "5")
    }

    // MARK: - YCAdError

    func testYCAdError_admobDomainMapping() {
        let notReadyErr = NSError(domain: "com.google.admob", code: 0, userInfo: [NSLocalizedDescriptionKey: "not ready"])
        XCTAssertEqual(YCAdError(notReadyErr), .notReady)

        let invalidIDErr = NSError(domain: "com.google.admob", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid"])
        XCTAssertEqual(YCAdError(invalidIDErr), .invalidAdUnitID)

        let expiredErr = NSError(domain: "com.google.admob", code: 9, userInfo: [NSLocalizedDescriptionKey: "expired"])
        XCTAssertEqual(YCAdError(expiredErr), .expired)

        let otherAdmobErr = NSError(domain: "com.google.admob", code: 42, userInfo: [NSLocalizedDescriptionKey: "other"])
        if case let .loadFailed(code, _) = YCAdError(otherAdmobErr) {
            XCTAssertEqual(code, 42)
        } else {
            XCTFail("期望 .loadFailed")
        }
    }

    func testYCAdError_nonAdmobDomainFallsBackToLoadFailed() {
        let nserr = NSError(domain: "com.other", code: 99, userInfo: [NSLocalizedDescriptionKey: "x"])
        if case let .loadFailed(code, _) = YCAdError(nserr) {
            XCTAssertEqual(code, 99)
        } else {
            XCTFail("期望 .loadFailed")
        }
    }

    func testYCAdError_wrap_preservesYCAdError() {
        let original = YCAdError.expired
        XCTAssertEqual(YCAdError.wrap(original), .expired)
    }

    func testYCAdError_localizedDescription() {
        XCTAssertNotNil(YCAdError.notReady.errorDescription)
        XCTAssertNotNil(YCAdError.expired.errorDescription)
        XCTAssertNotNil(YCAdError.loadFailed(code: 1, message: "x").errorDescription)
    }

    // MARK: - YCAdCenter ID Routing

    @MainActor
    func testYCAdCenter_resolve_returnsInputWhenTestModeOff() {
        let original = YCAdCenter.configuration
        defer { YCAdCenter.configuration = original }
        var config = YCAdConfiguration()
        config.testMode = false
        YCAdCenter.configuration = config
        let resolved = YCAdCenter.resolve(adUnitID: "ca-app-pub-xxx/yyy", for: .interstitial)
        XCTAssertEqual(resolved, "ca-app-pub-xxx/yyy")
    }

    @MainActor
    func testYCAdCenter_resolve_usesOfficialDefaultTestIDWhenTestModeOn() {
        let original = YCAdCenter.configuration
        defer { YCAdCenter.configuration = original }
        var config = YCAdConfiguration()
        config.testMode = true
        config.testAdUnitIDs = [:]   // 不覆盖，用官方默认
        YCAdCenter.configuration = config
        XCTAssertEqual(YCAdCenter.resolve(adUnitID: "anything", for: .banner), YCAdInternal.officialTestAdUnitIDs[.banner])
        XCTAssertEqual(YCAdCenter.resolve(adUnitID: "anything", for: .interstitial), YCAdInternal.officialTestAdUnitIDs[.interstitial])
        XCTAssertEqual(YCAdCenter.resolve(adUnitID: "anything", for: .rewarded), YCAdInternal.officialTestAdUnitIDs[.rewarded])
        XCTAssertEqual(YCAdCenter.resolve(adUnitID: "anything", for: .appOpen), YCAdInternal.officialTestAdUnitIDs[.appOpen])
        XCTAssertEqual(YCAdCenter.resolve(adUnitID: "anything", for: .native), YCAdInternal.officialTestAdUnitIDs[.native])
    }

    @MainActor
    func testYCAdCenter_resolve_prefersUserCustomTestIDOverOfficial() {
        let original = YCAdCenter.configuration
        defer { YCAdCenter.configuration = original }
        var config = YCAdConfiguration()
        config.testMode = true
        config.testAdUnitIDs = [.banner: "ca-app-pub-user/custom-banner"]
        YCAdCenter.configuration = config
        XCTAssertEqual(YCAdCenter.resolve(adUnitID: "ignored", for: .banner), "ca-app-pub-user/custom-banner")
        // 未覆盖的类型仍走官方默认
        XCTAssertEqual(YCAdCenter.resolve(adUnitID: "ignored", for: .interstitial), YCAdInternal.officialTestAdUnitIDs[.interstitial])
    }

    @MainActor
    func testYCAdInternal_currentTestAdUnitID_fallsBackToOfficial() {
        let original = YCAdCenter.configuration
        defer { YCAdCenter.configuration = original }
        var config = YCAdConfiguration()
        config.testAdUnitIDs = [:]
        YCAdCenter.configuration = config
        XCTAssertEqual(YCAdInternal.currentTestAdUnitID(for: .rewarded), YCAdInternal.officialTestAdUnitIDs[.rewarded])
    }

    // MARK: - YCAdState

    func testYCAdState_equality() {
        XCTAssertEqual(YCAdState.idle, .idle)
        XCTAssertNotEqual(YCAdState.idle, .loading)
        XCTAssertEqual(YCAdState.finished(.dismissed), .finished(.dismissed))
        XCTAssertNotEqual(YCAdState.finished(.dismissed), .finished(.rewarded(amount: 10, type: "coin")))
        XCTAssertEqual(YCAdState.finished(.rewarded(amount: 10, type: "coin")), .finished(.rewarded(amount: 10, type: "coin")))
    }

    // MARK: - YCAdConfiguration

    func testYCAdConfiguration_defaultValues() {
        let config = YCAdConfiguration()
        XCTAssertFalse(config.testMode)
        XCTAssertTrue(config.markDeviceAsTestDevice)
        XCTAssertNil(config.tagForUnderAge)
        XCTAssertNil(config.maxAdContentRating)
        XCTAssertTrue(config.testAdUnitIDs.isEmpty)
    }

    @MainActor
    func testYCAdConfiguration_sendableMutationThroughCenterTriggersSideEffect() {
        let original = YCAdCenter.configuration
        defer { YCAdCenter.configuration = original }
        var config = YCAdConfiguration()
        config.testMode = false
        YCAdCenter.configuration = config
        XCTAssertFalse(YCAdCenter.configuration.testMode)
        // 切换 testMode
        var newConfig = YCAdCenter.configuration
        newConfig.testMode = true
        YCAdCenter.configuration = newConfig
        XCTAssertTrue(YCAdCenter.configuration.testMode)
    }
}
