import Foundation
import UIKit
import GoogleMobileAds

/// 全屏广告（Interstitial / Rewarded / AppOpen）共享的 delegate→continuation 桥接器。
///
/// v13 的 `FullScreenContentDelegate` 是回调式：adWillPresent / adDidDismiss / didFailToPresentContentWithError。
/// `YCPresentBox` 把这些回调收敛为一次 `withCheckedThrowingContinuation` 的 resume：
/// - didFailToPresent → resume(throwing:)
/// - adDidDismiss     → resume(returning: result)
/// - Rewarded 的 userDidEarnReward → 更新 result 为 .rewarded(...)，等 dismiss 时一并 resume
@MainActor
final class YCPresentBox: NSObject, FullScreenContentDelegate {

    /// 持有的 continuation。resume 后置 nil。
    var cont: CheckedContinuation<YCAdShowResult, Error>?

    /// dismiss 时返回的结果。Rewarded 通过 `setReward` 改为 `.rewarded(...)`，其他默认 `.dismissed`。
    var result: YCAdShowResult = .dismissed

    /// 广告类型，用于日志
    let adType: YCAdType

    /// dismiss / 失败后回调（供 owner 清理 ad 引用、切状态），传入最终 result。
    var onDismiss: ((YCAdShowResult) -> Void)?

    /// 仅 Rewarded 用：present 前注入的奖励信息（从 ad.adReward 读取）。
    /// userDidEarnReward completionHandler 触发时取出并写入 result。
    var rewardInfo: YCRewardInfo?

    init(adType: YCAdType, onDismiss: @escaping (YCAdShowResult) -> Void) {
        self.adType = adType
        self.onDismiss = onDismiss
        super.init()
    }

    /// 仅 Rewarded 调用：在 present(from:) 的 completionHandler 里更新结果
    func setReward(amount: NSDecimalNumber, type: String) {
        let amt = amount.intValue
        result = .rewarded(amount: amt, type: type)
        YCAdLogger.info("获得奖励 [\(adType.rawValue)] amount=\(amt) type=\(type)")
    }

    // MARK: - FullScreenContentDelegate
    // 协议方法已通过 NS_SWIFT_UI_ACTOR 标注为 @MainActor，无需 nonisolated + Task hop。

    func ad(_ ad: AnyObject, didFailToPresentContentWithError error: Error) {
        YCAdLogger.error("present 失败 [\(adType.rawValue)]: \(error.localizedDescription)")
        let nserr = error as NSError
        let ycerr = YCAdError.presentFailed(code: nserr.code, message: nserr.localizedDescription)
        cont?.resume(throwing: ycerr)
        cont = nil
        onDismiss?(result)
    }

    func adDidDismissFullScreenContent(_ ad: AnyObject) {
        YCAdLogger.info("dismiss [\(adType.rawValue)]")
        cont?.resume(returning: result)
        cont = nil
        onDismiss?(result)
    }

    func adWillPresentFullScreenContent(_ ad: AnyObject) {
        YCAdLogger.debug("present 成功 [\(adType.rawValue)]")
    }

    func adDidRecordImpression(_ ad: AnyObject) {
        YCAdLogger.debug("记录曝光 [\(adType.rawValue)]")
    }

    func adDidRecordClick(_ ad: AnyObject) {
        YCAdLogger.debug("记录点击 [\(adType.rawValue)]")
    }
}

/// 全屏广告协议。Interstitial / Rewarded / AppOpen 实现。
@MainActor
public protocol YCFullScreenAd: AnyObject {
    var state: YCAdState { get }
    var isReady: Bool { get }
    func load() async throws
    func present(from vc: UIViewController?) async throws -> YCAdShowResult
    func preloadIfNeeded() async
}

extension YCFullScreenAd {
    /// 默认实现：状态为 .ready 才算就绪
    public var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// 默认实现：dismiss 后自动预加载下一条
    public func preloadIfNeeded() async {
        guard !isReady else { return }
        do {
            try await load()
        } catch {
            YCAdLogger.warn("预加载失败 [\(Self.self)]: \(error.localizedDescription)")
        }
    }
}
