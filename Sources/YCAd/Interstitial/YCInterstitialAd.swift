import Foundation
import UIKit
import GoogleMobileAds

/// UIKit / SwiftUI 通用 Interstitial 插屏广告。
///
/// 用法：
/// ```swift
/// let ad = YCInterstitialAd(adUnitID: "你的-interstitial-id")
/// try await ad.load()
/// let result = try await ad.present(from: nil)
/// switch result {
/// case .dismissed: print("广告关闭")
/// case .rewarded:  assertionFailure("Interstitial 不会返回 rewarded")
/// }
/// ```
@MainActor
public final class YCInterstitialAd: YCFullScreenAd {

    public private(set) var state: YCAdState = .idle

    private let adUnitID: String
    private var ad: InterstitialAd?
    private var box: YCPresentBox?

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public func load() async throws {
        guard state != .loading else { throw YCAdError.busy }
        let resolvedID = YCAdCenter.resolve(adUnitID: adUnitID, for: .interstitial)
        state = .loading
        YCAdLogger.info("Interstitial load 开始 id=\(resolvedID)")
        do {
            ad = try await InterstitialAd.load(with: resolvedID, request: Request())
            state = .ready
            YCAdLogger.info("Interstitial 加载成功")
        } catch {
            state = .failed
            YCAdLogger.error("Interstitial 加载失败: \(error.localizedDescription)")
            throw YCAdError.wrap(error)
        }
    }

    public func present(from vc: UIViewController?) async throws -> YCAdShowResult {
        guard let ad else { throw YCAdError.notReady }
        let presenter = vc ?? YCAdInternal.topmostViewController()
        guard let presenter else {
            throw YCAdError.presentFailed(code: -1, message: "找不到顶层 UIViewController")
        }
        guard state == .ready else { throw YCAdError.notReady }

        state = .showing
        let box = YCPresentBox(adType: .interstitial) { [weak self] in
            // dismiss / 失败后清理
            self?.ad = nil
            self?.box = nil
            self?.state = .finished(.dismissed)
        }
        self.box = box
        ad.fullScreenContentDelegate = box
        YCAdLogger.info("Interstitial present 开始")

        return try await withCheckedThrowingContinuation { cont in
            box.cont = cont
            ad.present(from: presenter)
        }
    }
}
