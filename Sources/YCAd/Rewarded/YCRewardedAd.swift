import Foundation
import UIKit
import GoogleMobileAds

/// UIKit / SwiftUI 通用 Rewarded 激励广告。
///
/// 用法：
/// ```swift
/// let ad = YCRewardedAd(adUnitID: "你的-rewarded-id")
/// try await ad.load()
/// let result = try await ad.present(from: nil)
/// if case let .rewarded(amount, type) = result {
///     print("用户获得奖励：\(amount) \(type)")
/// }
/// ```
@MainActor
public final class YCRewardedAd: YCFullScreenAd {

    public private(set) var state: YCAdState = .idle

    private let adUnitID: String
    private var ad: RewardedAd?
    private var box: YCPresentBox?

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public func load() async throws {
        guard state != .loading else { throw YCAdError.busy }
        let resolvedID = YCAdCenter.resolve(adUnitID: adUnitID, for: .rewarded)
        state = .loading
        YCAdLogger.info("Rewarded load 开始 id=\(resolvedID)")
        do {
            ad = try await RewardedAd.load(with: resolvedID, request: Request())
            state = .ready
            if let r = ad?.adReward {
                YCAdLogger.info("Rewarded 加载成功 reward=\(r.amount) \(r.type)")
            } else {
                YCAdLogger.info("Rewarded 加载成功")
            }
        } catch {
            state = .failed
            YCAdLogger.error("Rewarded 加载失败: \(error.localizedDescription)")
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
        let reward = ad.adReward
        let box = YCPresentBox(adType: .rewarded) { [weak self] result in
            self?.ad = nil
            self?.box = nil
            self?.state = .finished(result)
        }
        box.rewardInfo = YCRewardInfo(amount: reward.amount, type: reward.type)
        self.box = box
        ad.fullScreenContentDelegate = box
        YCAdLogger.info("Rewarded present 开始 reward=\(reward.amount) \(reward.type)")

        return try await withCheckedThrowingContinuation { cont in
            box.cont = cont
            ad.present(from: presenter) { [weak box] in
                // userDidEarnReward：更新结果为 .rewarded，等 dismiss 时一并 resume
                guard let box, let info = box.rewardInfo else { return }
                box.setReward(amount: info.amount, type: info.type)
            }
        }
    }
}

/// 奖励信息
public struct YCRewardInfo: Sendable {
    public let amount: NSDecimalNumber
    public let type: String
}
