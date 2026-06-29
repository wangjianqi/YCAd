import CoreGraphics
import GoogleMobileAds

/// YCAd 支持的广告类型
public enum YCAdType: String, Sendable, CaseIterable {
    case banner
    case interstitial
    case rewarded
    case appOpen
    case native

    public var displayName: String {
        switch self {
        case .banner:      return "Banner 横幅"
        case .interstitial: return "Interstitial 插屏"
        case .rewarded:    return "Rewarded 激励"
        case .appOpen:     return "App Open 开屏"
        case .native:      return "Native 原生"
        }
    }
}

/// Banner 广告尺寸枚举。`.adaptive` 走 v13 的 `largeAnchoredAdaptiveBanner(width:)`。
public enum YCAdSize: Sendable {
    case banner
    case largeBanner
    case fullBanner
    case mediumRectangle
    case leaderboard
    case adaptive

    /// 把 YCAdSize 解析为 GoogleMobileAds 的 `AdSize`。
    /// `.adaptive` 需要传入容器宽度；其他 case 忽略 width。
    @MainActor
    public func resolve(width: CGFloat) -> AdSize {
        switch self {
        case .adaptive:       return largeAnchoredAdaptiveBanner(width: width)
        case .banner:         return AdSizeBanner
        case .largeBanner:    return AdSizeLargeBanner
        case .fullBanner:     return AdSizeFullBanner
        case .mediumRectangle: return AdSizeMediumRectangle
        case .leaderboard:    return AdSizeLeaderboard
        }
    }
}

/// 全屏广告的状态机
public enum YCAdState: Sendable, Equatable {
    case idle
    case loading
    case ready
    case showing
    case finished(YCAdShowResult)
    case failed
}

/// `present` 完成时的结果
public enum YCAdShowResult: Sendable, Equatable {
    /// 广告被关闭（未获得奖励 / 非激励广告）
    case dismissed
    /// 用户完整观看且满足奖励条件
    case rewarded(amount: Int, type: String)
}

/// AdMob 内容分级
public enum YCAdContentRating: Sendable {
    case general
    case parentalGuidance
    case teen
    case matureAudience
}

/// 内部加载状态（与外部状态机配套）
enum YCLoadStatus: Sendable {
    case idle
    case loading
    case ready
    case failed
}
