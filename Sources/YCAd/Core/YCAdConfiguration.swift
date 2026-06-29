import Foundation

/// 全局配置。`configure(_:)` 时拷贝一份存到 `YCAdCenter.configuration`。
public struct YCAdConfiguration: Sendable {
    /// 是否启用测试模式。开启时强制使用测试广告单元 ID（用户配置优先，否则官方默认）。
    public var testMode: Bool = false

    /// 用户自定义测试广告单元 ID。testMode = true 时优先使用，覆盖官方默认测试 ID。
    public var testAdUnitIDs: [YCAdType: String] = [:]

    /// 是否把当前设备加入 `RequestConfiguration.testDeviceIdentifiers`。
    /// 即使误用真实广告 ID，也只返回测试广告，双保险防封号。
    public var markDeviceAsTestDevice: Bool = true

    /// 是否标记未成年用户（COPPA / GDPR 年龄合规）
    public var tagForUnderAge: Bool? = nil

    /// 内容分级
    public var maxAdContentRating: YCAdContentRating? = nil

    /// 日志级别。默认 `.info`(Debug) / `.none`(Release)
    public var logLevel: YCAdLogLevel = .defaultLevel

    public init() {}
}
