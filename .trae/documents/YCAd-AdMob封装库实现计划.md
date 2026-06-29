# YCAd - AdMob 广告封装库实现计划

## Context（背景）

当前每个 iOS 项目要接入 AdMob 都要从零写一遍 Banner / Interstitial / Rewarded / App Open / Native 五种广告的加载、展示、delegate 转换、SwiftUI 桥接代码，重复劳动大且容易踩 v13.x 的并发与生命周期坑。本项目封装一个 Swift Package `YCAd`，提供统一的 @MainActor final class API，对外屏蔽 GoogleMobileAds SDK v13.x 的细节，让其他项目通过 SPM 一行依赖即可集成。目标 iOS 17.6+，依赖 GoogleMobileAds v13.x（已支持 Swift 6 严格并发、@MainActor 隔离、async/await）。

---

## 技术选型（已确认）

| 项 | 决策 | 理由 |
|---|---|---|
| 隔离模型 | `@MainActor final class`（不用 actor） | SDK delegate 已 @MainActor，actor 会反复 hop 且无法持有非 Sendable 的 UIView/VC |
| 并发 | `swiftLanguageVersions: [.v6]` | SDK v13 全 @MainActor，开 .v6 让编译器强制 data-race 安全 |
| 部署目标 | `platforms: [.iOS("17.6")]` | 无 `.v17_6` 枚举，用字符串字面量 |
| 初始化 | 不传 appID | v13 从 Info.plist 读 `GADApplicationIdentifier` |
| UMP 顺序 | `YCAdCenter` 内强制 canRequestAds → start() | 否则违规请求 |
| 测试 ID | 内置官方测试 ID + 用户可在 configuration 覆盖 + testMode 时强制用测试 ID | 防开发期误用真实 ID 被封号；保留用户自定义测试 ID 的能力 |
| 测试设备 | 把当前设备加入 `RequestConfiguration.testDeviceIdentifiers` | 即使误用真实 ID 也只返回测试广告，双保险 |
| 日志 | Debug 构建默认 .info / Release 默认 .none，可运行时修改 | 默认开发可见、生产静默；调试页面可实时查看 |
| Banner 尺寸 | 新 `largeAnchoredAdaptiveBanner(width:)` | 旧 `currentOrientationAnchoredAdaptiveBanner` 已废弃 |
| 调试页面 | UIKit + SwiftUI 双版本 | 与库主体 API 风格一致 |

---

## 包结构

```
YCAd/
├── Package.swift
├── README.md
├── Sources/YCAd/
│   ├── Core/
│   │   ├── YCAdCenter.swift                 # 全局入口：configure / requestConsent / 测试 ID 路由
│   │   ├── YCAdConfiguration.swift           # 配置：testMode / 测试 ID 集合 / 标记设备 / contentRating
│   │   ├── YCAdError.swift                   # 错误枚举 + NSError 映射
│   │   ├── YCAdTypes.swift                   # YCAdSize / YCAdState / YCAdShowResult / YCAdType
│   │   ├── YCAdLogger.swift                  # 日志系统：分级 + 实时缓冲 + 自定义 sink
│   │   ├── YCFullScreenAdController.swift    # 全屏广告状态机 + delegate→async 桥接（核心复用）
│   │   └── YCAdInternal.swift                # rootVC 查找 / 测试 ID 默认表 / 设备 ID
│   ├── Banner/
│   │   ├── YCBannerAd.swift                  # UIKit 命令式 API
│   │   └── YCBannerView.swift                # SwiftUI UIViewRepresentable
│   ├── Interstitial/
│   │   └── YCInterstitialAd.swift
│   ├── Rewarded/
│   │   └── YCRewardedAd.swift
│   ├── AppOpen/
│   │   ├── YCAppOpenAd.swift
│   │   └── YCAppOpenAdLifecycleObserver.swift  # 冷热启动 / 防抖 / 4h 过期
│   ├── Native/
│   │   ├── YCNativeAd.swift                  # ObservableObject，加载数据
│   │   ├── YCNativeAdLoader.swift            # AdLoader + delegate
│   │   └── YCNativeAdView.swift              # SwiftUI 默认模板（UIKit 容器）
│   └── Debug/
│       ├── YCAdDebugViewController.swift     # UIKit 调试页面
│       └── YCAdDebugView.swift               # SwiftUI 调试页面
└── Tests/YCAdTests/
    └── YCAdTests.swift                       # 基本签名/状态机/ID 路由/日志测试（不依赖网络）
```

---

## 核心 API 草案

### YCAdCenter（入口）
```swift
@MainActor public enum YCAdCenter {
    public static var isInitialized: Bool { get }
    public static var canRequestAds: Bool { get }     // = UMP.canRequestAds
    public static var configuration: YCAdConfiguration { get set }
    public static var deviceID: String { get }        // identifierForVendor，供调试页面复制
    public static var sdkVersion: String { get }      // MobileAds.shared.sdkVersion
    public static var appID: String { get }           // 从 Info.plist GADApplicationIdentifier 读

    // 1. 配置（不传 appID，v13 从 Info.plist 读）
    public static func configure(_ configuration: YCAdConfiguration = .init()) async

    // 2. UMP 同意流程（必须在 configure 前或后调用，但 start() 一定在 canRequestAds 后）
    public static func requestConsent(from vc: UIViewController?) async throws

    // 3. 内部：根据 testMode + type 路由真实 ID / 测试 ID
    //    testMode = true → 优先 configuration.testAdUnitIDs[type]，否则用官方默认测试 ID
    //    testMode = false → 返回调用方传入的 adUnitID
    static func resolve(adUnitID: String, for type: YCAdType) -> String
}
```

### YCAdConfiguration
```swift
public struct YCAdConfiguration: Sendable {
    public var testMode: Bool = false
    public var testAdUnitIDs: [YCAdType: String] = [:]   // 用户自定义测试 ID，覆盖官方默认
    public var markDeviceAsTestDevice: Bool = true       // 加入 RequestConfiguration.testDeviceIdentifiers
    public var tagForUnderAge: Bool? = nil
    public var maxAdContentRating: YCAdContentRating? = nil
    public var logLevel: YCAdLogLevel = .defaultLevel    // 默认 .info(Debug) / .none(Release)
    public init() {}
}
```

### YCAdSize
```swift
public enum YCAdSize {
    case banner, largeBanner, fullBanner, mediumRectangle, leaderboard, adaptive
    func resolve(width: CGFloat) -> AdSize   // .adaptive → largeAnchoredAdaptiveBanner(width:)
}
```

### YCAdLogger（日志系统）
```swift
public enum YCAdLogLevel: Int, Sendable, Comparable {
    case debug = 0, info = 1, warning = 2, error = 3
    case none = 99
    public static func < (lhs: YCAdLogLevel, rhs: YCAdLogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
    public static let defaultLevel: YCAdLogLevel = {
        #if DEBUG
        return .info
        #else
        return .none
        #endif
    }()
}

public struct YCAdLogEntry: Sendable, Identifiable {
    public let id = UUID()
    public let level: YCAdLogLevel
    public let message: String
    public let time: Date
}

@MainActor public final class YCAdLogger: ObservableObject {
    public static let shared = YCAdLogger()
    public var level: YCAdLogLevel = .defaultLevel
    public var maxBufferedEntries: Int = 500
    @Published public private(set) var entries: [YCAdLogEntry] = []
    public var customSink: ((YCAdLogEntry) -> Void)?   // 额外输出（如 OSLog / 文件）

    public func clear()
    public func log(_ level: YCAdLogLevel, _ message: @autoclosure () -> String)

    // 供非 @MainActor 上下文调用（内部 Task hop 到 main）
    nonisolated public static func debug(_ message: @autoclosure () -> String)
    nonisolated public static func info(_ message: @autoclosure () -> String)
    nonisolated public static func warn(_ message: @autoclosure () -> String)
    nonisolated public static func error(_ message: @autoclosure () -> String)
}
```

### YCAdError
```swift
public enum YCAdError: Error, Sendable {
    case notReady, expired, invalidAdUnitID, consentRequired
    case loadFailed(code: Int, message: String)
    case presentFailed(code: Int, message: String)
    init(_ nsError: NSError)   // 映射 com.google.admob domain
}
```

### YCFullScreenAdController（核心复用层）
```swift
public enum YCAdState: Sendable { case idle, loading, ready, showing, finished(YCAdShowResult) }
public enum YCAdShowResult: Sendable {
    case dismissed
    case rewarded(amount: Int, type: String)
}

@MainActor public final class YCPresentBox: NSObject, FullScreenContentDelegate {
    var cont: CheckedContinuation<YCAdShowResult, Error>?
    var result: YCAdShowResult = .dismissed
    // ad(_:didFailToPresent:) → resume(throwing: YCAdError.presentFailed)
    // adDidDismissFullScreenContent → resume(returning: result)
    // Rewarded 的 userDidEarnReward 更新 result = .rewarded(...)
}

@MainActor public protocol YCFullScreenAd: AnyObject {
    var state: YCAdState { get }
    func load() async throws
    func present(from vc: UIViewController) async throws -> YCAdShowResult
    func preloadIfNeeded() async
}
```
Interstitial / Rewarded / AppOpen 三者组合 `YCFullScreenAdController`，只特化 `makeAd()` / reward 解析。

### Banner
```swift
// UIKit 命令式
@MainActor public final class YCBannerAd {
    public init(adUnitID: String, size: YCAdSize = .adaptive)
    public func load() async throws
    public func makeUIView(in vc: UIViewController) -> UIView   // 内部持 BannerView，不外泄 SDK 类型
    public var isReady: Bool { get }
}

// SwiftUI
public struct YCBannerView: View {
    public init(adUnitID: String, size: YCAdSize = .adaptive)
    public var body: some View   // UIViewRepresentable，宽度跟随 frame，adSize 变化时 reload
}
```

### Interstitial / Rewarded
```swift
@MainActor public final class YCInterstitialAd: YCFullScreenAd {
    public init(adUnitID: String)
    public func load() async throws
    public func present(from vc: UIViewController? = nil) async throws -> YCAdShowResult
    // 默认 vc = 顶层 rootVC（沿 presentedViewController 走到底）
}

@MainActor public final class YCRewardedAd: YCFullScreenAd {
    public init(adUnitID: String)
    public func load() async throws
    public func present(from vc: UIViewController? = nil) async throws -> YCAdShowResult
    // .rewarded(amount:type:) 仅当用户完整观看并满足奖励条件时返回
}
```

### App Open
```swift
@MainActor public final class YCAppOpenAd: YCFullScreenAd {
    public init(adUnitID: String)
    public func load() async throws
    public func present(from vc: UIViewController? = nil) async throws -> YCAdShowResult
}

@MainActor public final class YCAppOpenAdLifecycleObserver {
    public static let shared = YCAppOpenAdLifecycleObserver()
    public func start(adUnitID: String)        // 监听 didBecomeActiveNotification
    public func stop()
    // 内部策略：
    //   - 冷启动（首次 didBecomeActive，hasLaunched == false）跳过不打断首启
    //   - 热启动展示；lastShownAt 间隔 < 30s 跳过；loadDate 超 4h 视为过期重载
    //   - 失败/过期静默降级，不抛错、不阻塞主流程
}
```

### Native
```swift
@MainActor public final class YCNativeAd: ObservableObject {
    public init(adUnitID: String)
    public func load() async throws
    @Published public private(set) var state: YCAdState
    public var nativeAd: NativeAd? { get }   // SwiftUI 模板需要时取出
}

public struct YCNativeAdView: View {
    public init(ad: YCNativeAd, style: YCNativeAdStyle = .default)
    public var body: some View   // UIViewRepresentable，内部用 NativeAdView 容器并注册点击/曝光
}
```

### Debug（调试页面）
```swift
// UIKit
@MainActor public final class YCAdDebugViewController: UIViewController {
    public init()
    public override func viewDidLoad()
    // 页面布局（ UITableView + sectioned）：
    //   1. 信息区：App ID（只读）/ SDK 版本 / 设备 ID + 复制按钮 / 当前 testMode 状态
    //   2. 配置区：testMode 开关（运行时切换，立即写入 YCAdCenter.configuration.testMode）
    //              / ID 模式 segmented（真实 ID / 测试 ID）
    //   3. 广告加载区：5 种广告类型 segmented
    //                 + adUnitID 输入框（testMode 关闭时用此 ID；开启时显示当前测试 ID）
    //                 + 加载 / 展示按钮 + 状态 label（含耗时、错误码）
    //                 + Banner 在页面内嵌预览，Interstitial/Rewarded/AppOpen 点击展示 present 全屏
    //   4. 日志面板：实时订阅 YCAdLogger.shared.$entries，自动滚动到底部，清空按钮
}

// SwiftUI
public struct YCAdDebugView: View {
    public init()
    public var body: some View   // 与 UIKit 版功能等价的 Form + List
}
```

---

## Package.swift（完整）

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YCAd",
    platforms: [.iOS("17.6")],
    products: [.library(name: "YCAd", targets: ["YCAd"])],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
                 from: "13.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
                 from: "3.0.0"),
    ],
    targets: [
        .target(name: "YCAd", dependencies: [
            .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            .product(name: "UserMessagingPlatform", package: "swift-package-manager-google-user-messaging-platform"),
        ]),
        .testTarget(name: "YCAdTests", dependencies: ["YCAd"]),
    ],
    swiftLanguageVersions: [.v6]
)
```

---

## 实施步骤

1. **创建 Package.swift 与目录骨架**（Sources/YCAd/Core, Banner, Interstitial, Rewarded, AppOpen, Native, Debug；Tests/YCAdTests）。
2. **Core 层**：
   - `YCAdTypes.swift`：YCAdSize / YCAdState / YCAdShowResult / YCAdType / YCAdContentRating 枚举。
   - `YCAdError.swift`：错误枚举 + NSError(domain: "com.google.admob") 映射。
   - `YCAdLogger.swift`：YCAdLogLevel / YCAdLogEntry / YCAdLogger（@MainActor ObservableObject，实时 entries，nonisolated 静态方法供跨线程调用）。
   - `YCAdConfiguration.swift`：testMode / testAdUnitIDs / markDeviceAsTestDevice / tagForUnderAge / maxAdContentRating / logLevel。
   - `YCAdInternal.swift`：rootVC 查找 / 官方默认测试 ID 常量表 / deviceID（identifierForVendor）/ appID（读 Info.plist）。
   - `YCAdCenter.swift`：configure / requestConsent / resolve(adUnitID:for:) / 应用 testDeviceIdentifiers / 写入 logger.level。
   - `YCFullScreenAdController.swift`：状态机 + YCPresentBox（delegate→continuation 桥接），所有内部动作调 `YCAdLogger.debug/info/warn/error`。
3. **Banner**：YCBannerAd + YCBannerView（UIViewRepresentable，宽度变化时换 adSize 重新 load）。
4. **Interstitial / Rewarded**：组合 YCFullScreenAdController，特化 load(with:) 和 reward 解析。
5. **App Open**：YCAppOpenAd + YCAppOpenAdLifecycleObserver（冷热启动 / 防抖 / 4h 过期 / 静默降级，每步打日志）。
6. **Native**：YCNativeAd（ObservableObject）+ YCNativeAdLoader（AdLoader + delegate）+ YCNativeAdView（默认 UIViewRepresentable 模板，注册 nativeAdView.nativeAd = ad 触发点击/曝光）。
7. **Debug 调试页面**：
   - `YCAdDebugViewController`（UIKit）：4 section（信息 / 配置 / 广告加载 / 日志），日志通过 Combine 订阅 `YCAdLogger.shared.$entries`。
   - `YCAdDebugView`（SwiftUI）：等价 Form + List 实现。
   - 复用主体 5 种广告 API，无需新增底层逻辑。
   - 设备 ID 复制：`UIPasteboard.general.string = YCAdCenter.deviceID`。
8. **README.md**：集成步骤（Info.plist 加 GADApplicationIdentifier、SKAdNetworkItems、NSAppTransportSecurity）、最小用法示例（5 种广告）、testMode / 自定义测试 ID 说明、调试页面调起方式（`present(YCAdDebugViewController(), animated:)` 或 SwiftUI `YCAdDebugView()`）、冷热启动说明、日志配置说明。
9. **本地验证**：`swift build` 编译通过；`swift test` 跑签名/状态机/ID 路由/日志缓冲单测（不依赖网络与真实 SDK 状态）。

---

## 验证方式（端到端）

1. **编译**：在 `/Users/WJQ/ai_opensource/YCAd` 下 `swift build` 应通过（SPM 自动拉取 GoogleMobileAds v13.x）。
2. **单测**：`swift test` 验证：
   - YCAdSize.resolve 各 case 正确映射
   - YCAdError(NSError) 映射 com.google.admob domain 错误
   - YCAdCenter.resolve 在 testMode 开/关下的 ID 路由（含用户自定义测试 ID 覆盖官方默认）
   - YCAdLogger 缓冲上限、level 过滤、clear
   - YCAdState 状态机迁移合法性
3. **真实集成**（可选，由用户在示例 App 工程验证）：
   - App 工程 Info.plist 加 `GADApplicationIdentifier = ca-app-pub-3940256099942544~1458002511`、SKAdNetworkItems。
   - `var config = YCAdConfiguration(); config.testMode = true; await YCAdCenter.configure(config)` → `try await YCAdCenter.requestConsent(from: nil)`。
   - 调试页面：`present(YCAdDebugViewController(), animated: true)`，在页面里：
     - 检查信息区显示正确的 App ID / SDK 版本 / 设备 ID，点复制按钮验证剪贴板
     - 切换 testMode 开关，验证日志打印配置变更
     - 选 Interstitial + 测试 ID → 加载 → 展示，应弹全屏测试广告，dismiss 后日志显示状态机迁移
     - 切到"真实 ID"模式（输入官方测试 ID 模拟真实路径）→ 加载，验证 testDeviceIdentifiers 生效（仍返回测试广告）
     - 日志面板实时滚动，清空按钮可用
   - SwiftUI 调试页面：在 SwiftUI 视图里 `YCAdDebugView()` 嵌入或 sheet 展示，功能与 UIKit 等价。
   - Banner：SwiftUI 加 `YCBannerView(adUnitID: "任意字符串，testMode 自动覆盖")` 应见测试横幅。
   - AppOpen：`YCAppOpenAdLifecycleObserver.shared.start(adUnitID:)`，App 进后台再回前台应弹测试广告，冷启动不弹。
   - Native：`YCNativeAd` + `YCNativeAdView` 应显示测试原生广告模板。

---

## 关键设计决策摘要

- **@MainActor final class** 而非 actor：避免与非 Sendable UIView/VC 跨 actor 隔离冲突，与 v13.x 的 @MainActor delegate 一致。
- **YCPresentBox + CheckedContinuation**：把 `FullScreenContentDelegate` 的回调式 API 转成 `present(from:) async throws -> YCAdShowResult`，三路径（didFailToPresent / dismiss / reward）都收敛。
- **YCFullScreenAdController** 泛型复用：Interstitial/Rewarded/AppOpen 共用状态机与 continuation 逻辑，只在 makeAd() 与 reward 处理处特化。
- **YCAdCenter.resolve** 测试 ID 路由：testMode 时优先用户配置的 `testAdUnitIDs[type]`，否则用官方默认测试 ID；同时 `markDeviceAsTestDevice` 把当前设备加入 `RequestConfiguration.testDeviceIdentifiers`，双保险防误用真实 ID 触发计费。
- **YCAdLogger**：@MainActor ObservableObject，@Published entries 供调试页面直接订阅；nonisolated 静态方法供 SDK 内任意线程调用，内部 Task hop 到 main；Debug 默认 .info / Release 默认 .none，可通过 configuration.logLevel 覆盖。
- **调试页面复用主体 API**：Debug 模块不重复实现广告加载，直接调用 YCBannerAd/YCInterstitialAd/YCRewardedAd/YCAppOpenAd/YCNativeAd；testMode 切换直接修改 `YCAdCenter.configuration.testMode` 立即生效。
- **App Open 冷启动跳过 + 30s 防抖 + 4h 过期**：避免打断首次启动、避免短时间多次回前台刷屏、避免展示过期广告。
- **SwiftUI rootVC 查找工具**：从 connectedScenes 取 key window → rootVC → 沿 presentedViewController 链走到底，全屏广告统一从这里取 present 容器。
