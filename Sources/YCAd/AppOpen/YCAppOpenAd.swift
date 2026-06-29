import Foundation
import UIKit
import GoogleMobileAds

/// UIKit / SwiftUI 通用 App Open 开屏广告。
///
/// 单次使用：`load()` 后 `present(from:)`。
/// 自动监听前后台切换：见 `YCAppOpenAdLifecycleObserver`。
@MainActor
public final class YCAppOpenAd: YCFullScreenAd {

    public private(set) var state: YCAdState = .idle

    /// 加载时间，用于 4 小时过期检查
    public private(set) var loadTime: Date?

    private let adUnitID: String
    private var ad: AppOpenAd?
    private var box: YCPresentBox?

    /// 4 小时过期阈值
    public static let expirationInterval: TimeInterval = 4 * 60 * 60

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    /// 是否已过期（load 后超过 4 小时）
    public var isExpired: Bool {
        guard let loadTime else { return true }
        return Date().timeIntervalSince(loadTime) >= Self.expirationInterval
    }

    public var isReady: Bool {
        if case .ready = state, !isExpired, ad != nil { return true }
        return false
    }

    public func load() async throws {
        guard state != .loading else { throw YCAdError.busy }
        let resolvedID = YCAdCenter.resolve(adUnitID: adUnitID, for: .appOpen)
        state = .loading
        YCAdLogger.info("AppOpen load 开始 id=\(resolvedID)")
        do {
            ad = try await AppOpenAd.load(with: resolvedID, request: Request())
            loadTime = Date()
            state = .ready
            YCAdLogger.info("AppOpen 加载成功")
        } catch {
            state = .failed
            YCAdLogger.error("AppOpen 加载失败: \(error.localizedDescription)")
            throw YCAdError.wrap(error)
        }
    }

    public func present(from vc: UIViewController?) async throws -> YCAdShowResult {
        guard let ad else { throw YCAdError.notReady }
        if isExpired { throw YCAdError.expired }

        let presenter = vc ?? YCAdInternal.topmostViewController()
        guard let presenter else {
            throw YCAdError.presentFailed(code: -1, message: "找不到顶层 UIViewController")
        }
        guard state == .ready else { throw YCAdError.notReady }

        state = .showing
        let box = YCPresentBox(adType: .appOpen) { [weak self] in
            self?.ad = nil
            self?.box = nil
            self?.state = .finished(.dismissed)
        }
        self.box = box
        ad.fullScreenContentDelegate = box
        YCAdLogger.info("AppOpen present 开始")

        return try await withCheckedThrowingContinuation { cont in
            box.cont = cont
            ad.present(from: presenter)
        }
    }
}
