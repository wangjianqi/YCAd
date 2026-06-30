---
name: "ycad-integration"
description: "Integrates the YCAd AdMob wrapper into iOS projects (SPM setup, init, 5 ad types, debug page). Invoke when adding/using AdMob, banners, interstitials, rewarded, app open, or native ads in an iOS app."
---

# YCAd 集成指南

YCAd 是基于 Google AdMob 的 Swift Package 广告封装库，支持 5 种广告类型（Banner / Interstitial / Rewarded / App Open / Native），提供 UIKit + SwiftUI 双层 API，内置 UMP 同意流程、测试模式、调试页面。

## 何时使用此 Skill

当用户在 iOS 项目（Swift / SwiftUI / UIKit）中需要：
- 集成广告（AdMob / 横幅 / 插屏 / 激励 / 开屏 / 原生）
- 添加 YCAd 依赖
- 初始化广告 SDK
- 调起广告调试页面

请按本指南操作。**始终先读取本指南再生成集成代码**，确保 API 签名正确。

## 前置条件

- iOS 17.6+
- Swift 6 / Xcode 16+
- Swift Package Manager
- YCAd 库源码（本地路径或 git 仓库）

## 集成步骤

### 1. 添加 SPM 依赖

在宿主项目的 `Package.swift`：

```swift
dependencies: [
    .package(path: "../../ai_opensource/YCAd"),  // 本地路径
    // 或 .package(url: "https://your-repo/YCAd.git", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "YCAd", package: "YCAd"),
    ]),
]
```

若是 Xcode 项目（非 SPM）：File → Add Package Dependencies → 输入 YCAd 路径或 URL → 勾选 `YCAd` library。

**注意**：YCAd 已传递依赖 GoogleMobileAds (13.x) 与 GoogleUserMessagingPlatform (3.x)，宿主项目无需单独添加。

### 2. 配置 Info.plist

AdMob 要求在 `Info.plist` 配置 App ID：

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXX~YYYYYY</string>
```

开发期可用官方测试 App ID：`ca-app-pub-3940256099942544~1458002511`

### 3. 初始化（App 启动时）

在 `AppDelegate.application(_:didFinishLaunchingWithOptions:)` 或 SwiftUI `App.init()` 中：

```swift
import YCAd

@main
struct YourApp: App {
    init() {
        Task { @MainActor in
            var config = YCAdConfiguration()
            config.testMode = true              // 开发期用测试广告 ID
            config.logLevel = .debug            // 详细日志
            config.markDeviceAsTestDevice = true // 双保险：当前设备强制返回测试广告
            await YCAdCenter.configure(config)
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

### 4. UMP 同意流程（首次启动 / 进入需要广告的页面）

欧盟用户需先完成 UMP（User Messaging Platform）同意流程：

```swift
// 通常在首个 ViewController 的 viewDidAppear 或启动后调用
try await YCAdCenter.requestConsent(from: viewController)
// 完成后用 YCAdCenter.canRequestAds 判断是否可请求广告
if YCAdCenter.canRequestAds {
    // 加载广告
}
```

`requestConsent` 内部已处理"若不需要同意则直接返回"，可安全调用。

## 五种广告用法

### Banner（横幅）

SwiftUI：
```swift
YCBannerView(adUnitID: "你的-banner-id", size: .adaptive)
    .frame(height: 60)
```

`size` 可选：`.adaptive`（推荐，按宽度自适应）/ `.banner` / `.largeBanner` / `.fullBanner` / `.mediumRectangle` / `.leaderboard`。

### Interstitial（插屏）

```swift
let ad = YCInterstitialAd(adUnitID: "你的-interstitial-id")
try await ad.load()                    // 预加载
// 适当时机展示：
let result: YCAdShowResult = try await ad.present(from: viewController)
```

### Rewarded（激励）

```swift
let ad = YCRewardedAd(adUnitID: "你的-rewarded-id")
try await ad.load()
let result: YCAdShowResult = try await ad.present(from: viewController)
switch result {
case .rewarded(let amount, let type):
    print("发放奖励：\(amount) \(type)")
case .dismissed:
    print("用户未看完")
}
```

### App Open（开屏）

通常配合生命周期观察，在 App 进入后台时预加载、回前台时展示：

```swift
let ad = YCAppOpenAd(adUnitID: "你的-appopen-id")
try await ad.load()
let result = try await ad.present(from: viewController)
```

YCAd 提供 `YCAppOpenAdLifecycleObserver` 可自动管理后台/前台切换的加载与展示（详见源码）。

### Native（原生）

YCNativeAd 是 ObservableObject，适合 SwiftUI 声明式用法：

```swift
// 在 View 中
@StateObject private var nativeAd = YCNativeAd(adUnitID: "你的-native-id")

var body: some View {
    VStack {
        if nativeAd.isReady {
            YCNativeAdView(ad: nativeAd, style: .default)
                .frame(height: 120)
        }
    }
    .task {
        try? await nativeAd.load()
    }
}
```

`YCNativeAdView` 内置默认模板（headline / body / icon / CTA / media）。`style` 可选 `.default` / `.compact`。

## 测试模式与广告单元 ID

### testMode（开发期）

`YCAdConfiguration.testMode = true` 时，YCAd 自动用官方测试广告单元 ID，避免误点真实广告被封号。各类型官方测试 ID 已内置，无需手动配。

### 自定义测试 ID

如有自己的测试 ID：
```swift
config.testAdUnitIDs = [
    .banner: "ca-app-pub-3940256099942544/2934735716",
    .interstitial: "ca-app-pub-3940256099942544/4448196360",
    .rewarded: "ca-app-pub-3940256099942544/1712485313",
    .appOpen: "ca-app-pub-3940256099942544/5662855259",
    .native: "ca-app-pub-3940256099942544/3986624511",
]
```

### 运行时切换 testMode

调试页面可运行时切换 testMode / 真实 ID，无需重新编译。

## 调试页面

### SwiftUI

```swift
struct DebugHost: View {
    var body: some View { YCAdDebugView() }
}
// 或用 sheet / fullScreenCover 呈现
```

### UIKit

```swift
let vc = YCAdDebugViewController()
present(UINavigationController(rootViewController: vc), animated: true)
```

调试页面功能：
- 查看 App ID / SDK 版本 / 设备 ID（可一键复制，用于 AdMob 测试设备注册）
- **一键关闭所有广告（紧急刹车）**：运行时禁用所有 load/present，App Open 观察者也跳过
- 运行时切换 testMode、真实/测试广告单元 ID
- 实时日志面板（订阅 `YCAdLogger.shared.entries`）
- 调整日志级别

## API 速查表

### YCAdCenter（全局入口，@MainActor）

| API | 说明 |
|---|---|
| `configure(_:) async` | 初始化 SDK，传入 YCAdConfiguration |
| `requestConsent(from:) async throws` | UMP 同意流程 |
| `canRequestAds: Bool` | 是否可请求广告（同意流程后） |
| `adsDisabled: Bool` | 全局广告总开关，true 时所有 load/present 抛 `.disabled`，调试页面可切换 |
| `guardAdsEnabled() throws` | 广告类入口检查，禁用时抛 `.disabled` |
| `configuration: YCAdConfiguration` | 当前配置（可运行时修改） |
| `appID / sdkVersion / deviceID: String` | 只读信息 |
| `resolve(adUnitID:for:) -> String` | 解析广告单元 ID（testMode 时返回测试 ID） |

### YCAdConfiguration 字段

| 字段 | 默认值 | 说明 |
|---|---|---|
| `testMode: Bool` | false | 测试模式，用测试广告单元 ID |
| `testAdUnitIDs: [YCAdType: String]` | [:] | 自定义测试 ID（覆盖官方默认） |
| `markDeviceAsTestDevice: Bool` | true | 把当前设备加入测试设备列表 |
| `tagForUnderAge: Bool?` | nil | 标记未成年（COPPA/GDPR 合规） |
| `maxAdContentRating: YCAdContentRating?` | nil | 内容分级 |
| `logLevel: YCAdLogLevel` | .info(Debug) / .none(Release) | 日志级别 |

### 广告类公共 API

所有全屏广告（Interstitial / Rewarded / App Open）签名一致：
```swift
public init(adUnitID: String)
public func load() async throws
public func present(from vc: UIViewController?) async throws -> YCAdShowResult
public var state: YCAdState  // idle/loading/ready/showing/finished/failed
public var isReady: Bool
```

Banner：`YCBannerView(adUnitID:size:)` — SwiftUI UIViewRepresentable
Native：`YCNativeAd(adUnitID:)` — ObservableObject，`load() async throws`，`YCNativeAdView(ad:style:)` 渲染

### YCAdShowResult

```swift
public enum YCAdShowResult: Sendable, Equatable {
    case dismissed                    // 广告关闭（非激励或未完成观看）
    case rewarded(amount: Int, type: String)  // 获得奖励
}
```

### YCAdError

```swift
public enum YCAdError: Error {
    case notReady / expired / disabled / invalidAdUnitID / consentRequired
    case loadFailed(code:message:) / presentFailed(code:message:) / busy
}
```

## 注意事项

1. **Info.plist 必须配 GADApplicationIdentifier**：YCAd 不处理此项，遗漏会导致 SDK 崩溃。
2. **主线程隔离**：所有 public API 均为 @MainActor，调用时需在主线程或 `Task { @MainActor in }` 中。
3. **present 的 viewController**：传 nil 时 YCAd 自动查找最顶层 VC；建议显式传入当前 VC 确保正确。
4. **App Open 冷启动**：YCAd 的 `YCAppOpenAdLifecycleObserver` 处理后台→前台切换；冷启动（首次启动）的开屏需自行在 splash 阶段加载并展示。
5. **Release 关闭日志**：`YCAdLogLevel.defaultLevel` 在 Release 构建自动为 `.none`，无需手动处理。
6. **不要在 Release 开 testMode**：上线前务必 `testMode = false`，否则只展示测试广告无收益。
7. **UMP 同意流程**：`requestConsent` 内部已判断是否需要展示表单，非欧盟用户会立即返回，可无条件调用。

## 常见集成模式

### 模式 A：SwiftUI App 完整初始化

```swift
@main
struct MyApp: App {
    @StateObject private var adReady = AdReadyModel()
    init() {
        Task { @MainActor in
            var config = YCAdConfiguration()
            #if DEBUG
            config.testMode = true
            config.logLevel = .debug
            #endif
            await YCAdCenter.configure(config)
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { try? await YCAdCenter.requestConsent(from: nil) }
        }
    }
}
```

### 模式 B：UIKit AppDelegate 初始化

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    Task { @MainActor in
        var config = YCAdConfiguration()
        config.testMode = true
        await YCAdCenter.configure(config)
        try? await YCAdCenter.requestConsent(from: window?.rootViewController)
    }
    return true
}
```

### 模式 C：工具函数加载并展示激励广告

```swift
@MainActor
func showRewardedAd(adUnitID: String, on vc: UIViewController?) async {
    do {
        let ad = YCRewardedAd(adUnitID: adUnitID)
        try await ad.load()
        let result = try await ad.present(from: vc)
        if case .rewarded(let amount, _) = result {
            // 发放奖励
        }
    } catch let error as YCAdError {
        YCAdLogger.error("激励广告失败: \(error)")
    } catch {
        YCAdLogger.error("未知错误: \(error)")
    }
}
```

## 验证集成成功

集成后按以下顺序验证：
1. 编译通过（`import YCAd` 不报错）
2. 启动 App 不崩溃（Info.plist 的 GADApplicationIdentifier 正确）
3. 调起调试页面：`YCAdDebugViewController`，能看到 App ID / SDK 版本 / 设备 ID
4. testMode = true 下加载任一广告类型，调试页面日志显示"加载成功"
5. 展示广告，能看到测试广告内容（Banner / 插屏 / 激励 / 开屏 / 原生）

如遇问题，优先查看调试页面日志面板的 `YCAdLogger` 输出。
