import Foundation
import UIKit
import GoogleMobileAds

/// 监听 UIApplication didBecomeActive，自动展示 App Open 广告。
///
/// 策略：
/// - 冷启动（首次 didBecomeActive，hasLaunched == false）：跳过，不打断首启
/// - 热启动：展示广告
/// - 30s 防抖：上次展示 < 30s 跳过
/// - 4h 过期：loadTime 超 4h 视为过期重载
/// - 失败/过期/无填充：静默降级，不抛错、不阻塞主流程
///
/// 用法：
/// ```swift
/// YCAppOpenAdLifecycleObserver.shared.start(adUnitID: "你的-appopen-id")
/// ```
@MainActor
public final class YCAppOpenAdLifecycleObserver {

    public static let shared = YCAppOpenAdLifecycleObserver()

    /// 防抖间隔（默认 30 秒）
    public var debounceInterval: TimeInterval = 30

    private var ad: YCAppOpenAd?
    private var adUnitID: String?
    private var hasLaunched = false
    private var lastShownAt: Date?
    private var isLoading = false
    private var isShowing = false

    private init() {}

    /// 开始监听。建议在 `YCAdCenter.configure()` 完成后调用。
    public func start(adUnitID: String) {
        if self.adUnitID != adUnitID {
            self.adUnitID = adUnitID
            self.ad = YCAppOpenAd(adUnitID: adUnitID)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        YCAdLogger.info("AppOpen lifecycle observer 已启动，adUnitID=\(adUnitID)")

        // 预加载一条
        Task { await preload() }
    }

    public func stop() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        YCAdLogger.info("AppOpen lifecycle observer 已停止")
    }

    // MARK: - Internal

    @objc private func onDidBecomeActive() {
        Task { @MainActor in
            self.handleBecomeActive()
        }
    }

    private func handleBecomeActive() {
        // 全局禁用时跳过
        if YCAdCenter.adsDisabled {
            YCAdLogger.debug("AppOpen adsDisabled，跳过")
            return
        }

        // 冷启动跳过
        if !hasLaunched {
            hasLaunched = true
            YCAdLogger.info("AppOpen 冷启动，跳过首次 didBecomeActive")
            return
        }

        // 正在展示或加载，跳过
        if isShowing || isLoading {
            YCAdLogger.debug("AppOpen 正在加载/展示，跳过")
            return
        }

        // 防抖
        if let last = lastShownAt, Date().timeIntervalSince(last) < debounceInterval {
            YCAdLogger.debug("AppOpen 防抖：距上次展示 < \(debounceInterval)s，跳过")
            return
        }

        // 没有就绪广告，先预加载
        guard let ad, ad.isReady else {
            YCAdLogger.debug("AppOpen 无就绪广告，触发预加载")
            Task { await preload() }
            return
        }

        // 展示
        Task { await show(ad: ad) }
    }

    private func preload() async {
        guard !YCAdCenter.adsDisabled else { return }
        guard !isLoading else { return }
        guard let ad else { return }
        if ad.isReady { return }   // 已就绪
        isLoading = true
        YCAdLogger.info("AppOpen 预加载开始")
        do {
            try await ad.load()
        } catch {
            YCAdLogger.warn("AppOpen 预加载失败（静默降级）: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func show(ad: YCAppOpenAd) async {
        guard !isShowing else { return }
        isShowing = true
        lastShownAt = Date()
        do {
            _ = try await ad.present(from: nil)
            YCAdLogger.info("AppOpen 展示完成（dismiss）")
        } catch {
            YCAdLogger.warn("AppOpen 展示失败（静默降级）: \(error.localizedDescription)")
        }
        isShowing = false

        // 展示完毕后预加载下一条
        Task { await preload() }
    }
}
