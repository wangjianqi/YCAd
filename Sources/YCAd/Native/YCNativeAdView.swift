import SwiftUI
import UIKit
import GoogleMobileAds

/// 原生广告模板样式
public enum YCNativeAdStyle: Sendable {
    case `default`
    case compact
}

/// SwiftUI 版 Native 原生广告视图（默认模板）。
///
/// 内部用 UIKit 的 `NativeAdView` 容器注册子视图，触发点击/曝光。
///
/// 用法：
/// ```swift
/// YCNativeAdView(ad: nativeAd)
///     .frame(height: 120)
/// ```
public struct YCNativeAdView: UIViewRepresentable {

    public let ad: YCNativeAd
    public let style: YCNativeAdStyle

    public init(ad: YCNativeAd, style: YCNativeAdStyle = .default) {
        self.ad = ad
        self.style = style
    }

    public func makeUIView(context: Context) -> YCNativeAdContainerView {
        let container = YCNativeAdContainerView()
        return container
    }

    public func updateUIView(_ uiView: YCNativeAdContainerView, context: Context) {
        uiView.apply(nativeAd: ad.nativeAd, style: style)
    }
}

/// UIKit 容器：实际持有 NativeAdView 与子视图
@MainActor
final class YCNativeAdContainerView: UIView {

    private var nativeAdView: NativeAdView?
    private var headlineLabel: UILabel!
    private var bodyLabel: UILabel!
    private var ctaButton: UIButton!
    private var iconImageView: UIImageView!
    private var mediaView: MediaView!
    private var advertiserLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupSubviews() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8
        clipsToBounds = true

        // 创建容器
        let nativeAdView = NativeAdView()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.backgroundColor = .clear
        addSubview(nativeAdView)
        NSLayoutConstraint.activate([
            nativeAdView.topAnchor.constraint(equalTo: topAnchor),
            nativeAdView.bottomAnchor.constraint(equalTo: bottomAnchor),
            nativeAdView.leadingAnchor.constraint(equalTo: leadingAnchor),
            nativeAdView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        self.nativeAdView = nativeAdView

        // icon
        let icon = UIImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.clipsToBounds = true
        icon.layer.cornerRadius = 4
        nativeAdView.addSubview(icon)
        nativeAdView.iconView = icon
        self.iconImageView = icon

        // headline
        let headline = UILabel()
        headline.translatesAutoresizingMaskIntoConstraints = false
        headline.font = .systemFont(ofSize: 15, weight: .semibold)
        headline.numberOfLines = 2
        nativeAdView.addSubview(headline)
        nativeAdView.headlineView = headline
        self.headlineLabel = headline

        // body
        let body = UILabel()
        body.translatesAutoresizingMaskIntoConstraints = false
        body.font = .systemFont(ofSize: 12)
        body.textColor = .secondaryLabel
        body.numberOfLines = 2
        nativeAdView.addSubview(body)
        nativeAdView.bodyView = body
        self.bodyLabel = body

        // advertiser
        let advertiser = UILabel()
        advertiser.translatesAutoresizingMaskIntoConstraints = false
        advertiser.font = .systemFont(ofSize: 11)
        advertiser.textColor = .tertiaryLabel
        nativeAdView.addSubview(advertiser)
        nativeAdView.advertiserView = advertiser
        self.advertiserLabel = advertiser

        // CTA
        let cta = UIButton(type: .system)
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        cta.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        cta.layer.cornerRadius = 4
        cta.backgroundColor = .link
        cta.setTitleColor(.white, for: .normal)
        cta.isUserInteractionEnabled = false   // 由 NativeAdView 接管点击
        nativeAdView.addSubview(cta)
        nativeAdView.callToActionView = cta
        self.ctaButton = cta

        // media
        let media = MediaView()
        media.translatesAutoresizingMaskIntoConstraints = false
        media.backgroundColor = .systemGray6
        media.layer.cornerRadius = 4
        media.clipsToBounds = true
        nativeAdView.addSubview(media)
        nativeAdView.mediaView = media
        self.mediaView = media

        // Layout（基础模板）
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            icon.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40),

            headline.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            headline.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            headline.trailingAnchor.constraint(equalTo: cta.leadingAnchor, constant: -8),

            body.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            body.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 4),
            body.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),

            advertiser.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            advertiser.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 4),

            cta.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            cta.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            cta.heightAnchor.constraint(equalToConstant: 30),

            media.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            media.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            media.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 8),
            media.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -12),
            media.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
    }

    func apply(nativeAd: NativeAd?, style: YCNativeAdStyle) {
        guard let nativeAd else {
            nativeAdView?.nativeAd = nil
            headlineLabel.text = nil
            bodyLabel.text = nil
            ctaButton.setTitle(nil, for: .normal)
            iconImageView.image = nil
            advertiserLabel.text = nil
            return
        }

        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        advertiserLabel.text = nativeAd.advertiser
        iconImageView.image = nativeAd.icon?.image
        mediaView.mediaContent = nativeAd.mediaContent

        // 必须最后赋值，注册点击/曝光
        nativeAdView?.nativeAd = nativeAd
    }
}
