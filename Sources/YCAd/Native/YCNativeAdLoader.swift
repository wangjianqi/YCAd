import Foundation
import UIKit
import GoogleMobileAds

/// NativeAd 非 Sendable，用 @unchecked 包装以通过 CheckedContinuation 跨 actor 传递。
/// 安全性：delegate 方法与 load() 均在 @MainActor，实际无数据竞争。
private struct NativeAdBox: @unchecked Sendable {
    let value: NativeAd
}

/// 内部 AdLoader 包装：把 NativeAdLoaderDelegate 的回调转成 async。
@MainActor
final class YCNativeAdLoader: NSObject, NativeAdLoaderDelegate {

    private let adUnitID: String
    private var adLoader: AdLoader?
    private var cont: CheckedContinuation<NativeAdBox, Error>?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
    }

    func load() async throws -> NativeAd {
        let box = try await withCheckedThrowingContinuation { cont in
            self.cont = cont
            let rootVC = YCAdInternal.topmostViewController()
            let loader = AdLoader(
                adUnitID: adUnitID,
                rootViewController: rootVC,
                adTypes: [AdLoaderAdType.native],
                options: nil
            )
            loader.delegate = self
            self.adLoader = loader
            loader.load(Request())
        }
        return box.value
    }

    // MARK: - NativeAdLoaderDelegate
    // 协议方法已通过 NS_SWIFT_UI_ACTOR 标注为 @MainActor，无需 nonisolated + Task hop。

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        YCAdLogger.info("Native adLoader didReceive")
        cont?.resume(returning: NativeAdBox(value: nativeAd))
        cont = nil
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        YCAdLogger.error("Native adLoader didFail: \(error.localizedDescription)")
        cont?.resume(throwing: YCAdError.wrap(error))
        cont = nil
    }
}
