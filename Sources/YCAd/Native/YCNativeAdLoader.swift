import Foundation
import UIKit
import GoogleMobileAds

/// 内部 AdLoader 包装：把 NativeAdLoaderDelegate 的回调转成 async。
@MainActor
final class YCNativeAdLoader: NSObject, NativeAdLoaderDelegate {

    private let adUnitID: String
    private var adLoader: AdLoader?
    private var cont: CheckedContinuation<NativeAd, Error>?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
    }

    func load() async throws -> NativeAd {
        return try await withCheckedThrowingContinuation { cont in
            self.cont = cont
            let rootVC = YCAdInternal.topmostViewController()
            let loader = AdLoader(
                adUnitID: adUnitID,
                rootViewController: rootVC,
                adTypes: [.native],
                options: nil
            )
            loader.delegate = self
            self.adLoader = loader
            loader.load(Request())
        }
    }

    // MARK: - NativeAdLoaderDelegate

    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            YCAdLogger.info("Native adLoader didReceive")
            self.cont?.resume(returning: nativeAd)
            self.cont = nil
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            YCAdLogger.error("Native adLoader didFail: \(error.localizedDescription)")
            self.cont?.resume(throwing: YCAdError.wrap(error))
            self.cont = nil
        }
    }
}
