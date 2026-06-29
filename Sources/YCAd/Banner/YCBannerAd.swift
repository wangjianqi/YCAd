import Foundation
import UIKit
import GoogleMobileAds

/// UIKit 命令式 Banner 广告。
///
/// 内部持有 `BannerView`，通过 `makeUIView(in:)` 取出供调用方加到视图层级；
/// 不直接暴露 SDK 类型。
@MainActor
public final class YCBannerAd: NSObject {

    /// 广告状态
    public private(set) var state: YCAdState = .idle

    private let adUnitID: String
    private let size: YCAdSize
    private var bannerView: BannerView?
    private var loadCont: CheckedContinuation<Void, Error>?
    private var currentWidth: CGFloat = 0

    public init(adUnitID: String, size: YCAdSize = .adaptive) {
        self.adUnitID = adUnitID
        self.size = size
        super.init()
    }

    /// 是否已就绪（loaded 且未过期）
    public var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// 加载广告。
    public func load(width: CGFloat) async throws {
        guard state != .loading else { throw YCAdError.busy }
        let resolvedID = YCAdCenter.resolve(adUnitID: adUnitID, for: .banner)
        currentWidth = width
        state = .loading
        YCAdLogger.info("Banner load 开始 id=\(resolvedID) width=\(width)")

        // 创建/复用 BannerView
        let banner: BannerView
        if let existing = bannerView {
            banner = existing
        } else {
            banner = BannerView(adSize: size.resolve(width: width))
            banner.adUnitID = resolvedID
            banner.delegate = self
            self.bannerView = banner
        }

        return try await withCheckedThrowingContinuation { cont in
            self.loadCont = cont
            banner.load(Request())
        }
    }

    /// 取出内部 BannerView 用于加到视图层级。调用方负责布局与 autolayout。
    /// - Parameter rootViewController: Banner 点击后跳转用的 root VC（一般传所在 VC）
    public func makeUIView(in rootViewController: UIViewController) -> UIView {
        guard let banner = bannerView else {
            let banner = BannerView(adSize: size.resolve(width: currentWidth > 0 ? currentWidth : rootViewController.view.bounds.width))
            banner.adUnitID = YCAdCenter.resolve(adUnitID: adUnitID, for: .banner)
            banner.delegate = self
            self.bannerView = banner
            return banner
        }
        banner.rootViewController = rootViewController
        return banner
    }

    /// 宽度变化时（如设备旋转）调用以重新计算 adSize 并 reload。
    public func updateWidth(_ width: CGFloat) async throws {
        guard abs(width - currentWidth) > 1 else { return }
        currentWidth = width
        if let banner = bannerView {
            // BannerView 不支持动态改 adSize，需重建
            banner.delegate = nil
            self.bannerView = nil
        }
        try await load(width: width)
    }
}

// MARK: - GADBannerViewDelegate

extension YCBannerAd: BannerViewDelegate {
    nonisolated func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor in
            YCAdLogger.info("Banner 加载成功")
            self.state = .ready
            self.loadCont?.resume()
            self.loadCont = nil
        }
    }

    nonisolated func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            YCAdLogger.error("Banner 加载失败: \(error.localizedDescription)")
            self.state = .failed
            self.loadCont?.resume(throwing: YCAdError.wrap(error))
            self.loadCont = nil
        }
    }

    nonisolated func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        Task { @MainActor in
            YCAdLogger.debug("Banner 曝光")
        }
    }

    nonisolated func bannerViewDidRecordClick(_ bannerView: BannerView) {
        Task { @MainActor in
            YCAdLogger.debug("Banner 点击")
        }
    }

    nonisolated func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        Task { @MainActor in
            YCAdLogger.debug("Banner willPresentScreen")
        }
    }

    nonisolated func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        Task { @MainActor in
            YCAdLogger.debug("Banner didDismissScreen")
        }
    }
}
