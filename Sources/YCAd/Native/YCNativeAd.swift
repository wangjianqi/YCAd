import Foundation
import UIKit
import GoogleMobileAds

/// SwiftUI / UIKit 通用的 Native 原生广告加载器（ObservableObject）。
///
/// 用法：
/// ```swift
/// let ad = YCNativeAd(adUnitID: "你的-native-id")
/// ad.load()
/// // 在 SwiftUI 视图里通过 YCNativeAdView(ad: ad) 展示
/// ```
@MainActor
public final class YCNativeAd: ObservableObject {

    @Published public private(set) var state: YCAdState = .idle

    /// 加载完成的 NativeAd（供 SwiftUI 模板渲染）。state == .ready 时非 nil。
    public private(set) var nativeAd: NativeAd?

    private let adUnitID: String
    private var loader: YCNativeAdLoader?

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public var isReady: Bool {
        if case .ready = state, nativeAd != nil { return true }
        return false
    }

    public func load() async throws {
        guard state != .loading else { throw YCAdError.busy }
        let resolvedID = YCAdCenter.resolve(adUnitID: adUnitID, for: .native)
        state = .loading
        YCAdLogger.info("Native load 开始 id=\(resolvedID)")

        let loader = YCNativeAdLoader(adUnitID: resolvedID)
        self.loader = loader
        do {
            let ad = try await loader.load()
            self.nativeAd = ad
            self.state = .ready
            YCAdLogger.info("Native 加载成功 headline=\(ad.headline ?? "")")
        } catch {
            self.state = .failed
            YCAdLogger.error("Native 加载失败: \(error.localizedDescription)")
            throw YCAdError.wrap(error)
        }
    }
}
