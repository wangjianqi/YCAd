import Foundation
import UIKit
import GoogleMobileAds

/// 内部工具：rootVC 查找 / 官方默认测试 ID / 设备 ID / App ID
enum YCAdInternal {

    /// 官方测试 App ID（iOS）
    static let officialTestAppID = "ca-app-pub-3940256099942544~1458002511"

    /// 官方测试广告单元 ID（iOS）
    static let officialTestAdUnitIDs: [YCAdType: String] = [
        .banner:      "ca-app-pub-3940256099942544/2435281174",
        .interstitial: "ca-app-pub-3940256099942544/4411468910",
        .rewarded:    "ca-app-pub-3940256099942544/1712485313",
        .appOpen:     "ca-app-pub-3940256099942544/5575463023",
        .native:      "ca-app-pub-3940256099942544/3986624511",
    ]

    /// 取当前测试广告单元 ID：优先用户配置，否则官方默认。
    @MainActor
    static func currentTestAdUnitID(for type: YCAdType) -> String {
        if let id = YCAdCenter.configuration.testAdUnitIDs[type] {
            return id
        }
        return officialTestAdUnitIDs[type] ?? ""
    }

    /// 从 Info.plist 读 GADApplicationIdentifier
    static func readAppIDFromInfoPlist() -> String {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
    }

    /// 设备 ID（identifierForVendor）。供调试页面复制用。
    static var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }

    /// 取顶层可见的 UIViewController 用于 present 全屏广告：
    /// 从 connectedScenes 取 key window → rootVC → 沿 presentedViewController 走到底。
    @MainActor
    static func topmostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              let root = window.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
