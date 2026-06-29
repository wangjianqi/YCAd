import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

/// YCAd 全局入口。
///
/// 典型用法：
/// ```swift
/// var config = YCAdConfiguration()
/// config.testMode = true
/// await YCAdCenter.configure(config)
/// try await YCAdCenter.requestConsent(from: nil)
/// // 现在可以创建并 load 广告
/// ```
@MainActor
public enum YCAdCenter {

    // MARK: - State

    /// 是否已初始化（已调用 `MobileAds.shared.start()` 并完成）
    public private(set) static var isInitialized: Bool = false

    /// UMP 同意流程是否允许请求广告
    public static var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    /// 当前配置（运行时可修改，如 testMode 切换）
    public static var configuration: YCAdConfiguration = .init() {
        didSet {
            applyConfigurationSideEffects(old: oldValue)
        }
    }

    /// 当前 App ID（从 Info.plist GADApplicationIdentifier 读）
    public static var appID: String {
        YCAdInternal.readAppIDFromInfoPlist()
    }

    /// SDK 版本号
    public static var sdkVersion: String {
        MobileAds.shared.sdkVersion
    }

    /// 设备 ID（identifierForVendor），供调试页面复制
    public static var deviceID: String {
        YCAdInternal.deviceID
    }

    // MARK: - Configure

    /// 初始化 SDK。会自动应用 configuration 中的 testDeviceIdentifiers / tagForUnderAge / maxAdContentRating / logLevel。
    /// 注意：必须在 `canRequestAds == true` 后才能调用 `start()`；如果当前 UMP 还未完成，此方法只做配置不 start。
    public static func configure(_ configuration: YCAdConfiguration = .init()) async {
        self.configuration = configuration
        YCAdLogger.shared.level = configuration.logLevel
        applyRequestConfiguration()

        YCAdLogger.info("YCAd configure: appID=\(appID), sdkVersion=\(sdkVersion), testMode=\(configuration.testMode), markDeviceAsTestDevice=\(configuration.markDeviceAsTestDevice)")

        guard canRequestAds else {
            YCAdLogger.warn("UMP canRequestAds = false，跳过 MobileAds.start()。请先调用 requestConsent(from:)。")
            return
        }

        guard !isInitialized else {
            YCAdLogger.debug("已初始化过，跳过重复 start()")
            return
        }

        let status = await MobileAds.shared.start()
        isInitialized = true
        YCAdLogger.info("MobileAds.start() 完成，adapter 状态数：\(status.adapterStatusesByClassName.count)")
    }

    /// 请求 UMP 同意流程。若需要展示同意表单则自动 present。
    /// - Parameter vc: 用于 present 同意表单的 ViewController。传 nil 时自动查找顶层 VC。
    public static func requestConsent(from vc: UIViewController?) async throws {
        let presenter = vc ?? YCAdInternal.topmostViewController()
        let params = RequestParameters()
        YCAdLogger.info("UMP requestConsentInfoUpdate 开始")

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: params) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }

        YCAdLogger.info("UMP loadAndPresentIfRequired 开始")
        try await ConsentInformation.shared.loadAndPresentIfRequired(from: presenter)

        let canReq = ConsentInformation.shared.canRequestAds
        YCAdLogger.info("UMP 完成，canRequestAds=\(canReq)")

        // 若 configure() 之前因 canRequestAds=false 跳过了 start()，这里补上
        if canReq, !isInitialized {
            let status = await MobileAds.shared.start()
            isInitialized = true
            YCAdLogger.info("UMP 通过后 MobileAds.start() 完成，adapter 状态数：\(status.adapterStatusesByClassName.count)")
        }
    }

    // MARK: - ID Routing

    /// 根据 testMode 路由广告单元 ID：
    /// - testMode = true：优先 configuration.testAdUnitIDs[type]，否则用官方默认测试 ID
    /// - testMode = false：返回调用方传入的 adUnitID
    public static func resolve(adUnitID: String, for type: YCAdType) -> String {
        if configuration.testMode {
            let resolved = YCAdInternal.currentTestAdUnitID(for: type)
            YCAdLogger.debug("resolve(\(type.rawValue)) testMode=true → \(resolved)")
            return resolved
        }
        return adUnitID
    }

    // MARK: - Private

    /// 把 configuration 应用到 SDK 的 RequestConfiguration
    private static func applyRequestConfiguration() {
        let reqConf = MobileAds.shared.requestConfiguration

        if configuration.markDeviceAsTestDevice {
            let deviceID = YCAdInternal.deviceID
            if !deviceID.isEmpty {
                reqConf.testDeviceIdentifiers = [deviceID]
                YCAdLogger.debug("已将本设备加入 testDeviceIdentifiers: \(deviceID)")
            }
        }

        if let underAge = configuration.tagForUnderAge {
            reqConf.tagForUnderAge(ofConsent: underAge)
        }

        if let rating = configuration.maxAdContentRating {
            switch rating {
            case .general:          reqConf.maxAdContentRating = .general
            case .parentalGuidance: reqConf.maxAdContentRating = .parentalGuidance
            case .teen:             reqConf.maxAdContentRating = .teen
            case .matureAudience:   reqConf.maxAdContentRating = .matureAudience
            }
        }
    }

    /// configuration 变更时的副作用（运行时切换 testMode 等）
    private static func applyConfigurationSideEffects(old: YCAdConfiguration) {
        if old.testMode != configuration.testMode {
            YCAdLogger.info("testMode 切换：\(old.testMode) → \(configuration.testMode)")
        }
        if old.markDeviceAsTestDevice != configuration.markDeviceAsTestDevice
            || old.tagForUnderAge != configuration.tagForUnderAge
            || old.maxAdContentRating != configuration.maxAdContentRating {
            applyRequestConfiguration()
        }
        if old.logLevel != configuration.logLevel {
            YCAdLogger.shared.level = configuration.logLevel
        }
    }
}
