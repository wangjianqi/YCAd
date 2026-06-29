import SwiftUI
import UIKit
import GoogleMobileAds

/// SwiftUI 版 Banner 广告视图。
///
/// 用法：
/// ```swift
/// YCBannerView(adUnitID: "你的-banner-adUnitID")
///     .frame(maxWidth: .infinity)
/// ```
public struct YCBannerView: UIViewRepresentable {

    public let adUnitID: String
    public let size: YCAdSize

    public init(adUnitID: String, size: YCAdSize = .adaptive) {
        self.adUnitID = adUnitID
        self.size = size
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(adUnitID: adUnitID, size: size)
    }

    public func makeUIView(context: Context) -> BannerContainerView {
        let container = BannerContainerView()
        context.coordinator.container = container
        return container
    }

    public func updateUIView(_ uiView: BannerContainerView, context: Context) {
        let width = uiView.bounds.width
        guard width > 0 else { return }
        Task { @MainActor in
            try? await context.coordinator.ensureLoaded(width: width, container: uiView)
        }
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator {
        let ad: YCBannerAd
        weak var container: BannerContainerView?
        private var loadedWidth: CGFloat = 0

        init(adUnitID: String, size: YCAdSize) {
            self.ad = YCBannerAd(adUnitID: adUnitID, size: size)
        }

        func ensureLoaded(width: CGFloat, container: BannerContainerView) async throws {
            // 宽度变化 > 1pt 时重新加载
            if abs(width - loadedWidth) > 1 {
                loadedWidth = width
                try await ad.load(width: width)
                mount(into: container)
            } else if container.bannerView == nil {
                // 首次挂载
                try await ad.load(width: width)
                mount(into: container)
            }
        }

        private func mount(into container: BannerContainerView) {
            // 移除旧 view
            container.bannerView?.removeFromSuperview()
            // 找 rootVC
            guard let rootVC = YCAdInternal.topmostViewController() else {
                YCAdLogger.warn("Banner 挂载失败：找不到 rootViewController")
                return
            }
            let banner = ad.makeUIView(in: rootVC) as! BannerView
            banner.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: container.topAnchor),
                banner.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                banner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            container.bannerView = banner
        }
    }
}

/// 容器视图：让 BannerView 自动撑高 SwiftUI frame
@MainActor
public final class BannerContainerView: UIView {
    var bannerView: BannerView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    public required init?(coder: NSCoder) { fatalError() }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // 让 SwiftUI 知道容器期望高度（按 banner intrinsicContentSize）
        if let banner = bannerView {
            invalidateIntrinsicContentSize()
            _ = banner
        }
    }

    public override var intrinsicContentSize: CGSize {
        if let banner = bannerView {
            return banner.intrinsicContentSize
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}
