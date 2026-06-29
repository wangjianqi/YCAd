# YCAd

基于 [GoogleMobileAds iOS SDK v13.x](https://developers.google.cn/admob/ios/rel-notes) 的 AdMob 广告封装库，通过 Swift Package Manager 分发。

- 5 种广告类型：Banner 横幅 / Interstitial 插屏 / Rewarded 激励 / App Open 开屏 / Native 原生
- UIKit + SwiftUI 双层 API
- iOS 17.6+，开启 Swift 6 严格并发（@MainActor 隔离）
- 内置 UMP 同意流程封装
- 测试 ID 路由（testMode 强制走官方测试 ID，用户可覆盖）
- 调试日志（Debug 默认 .info / Release 默认 .none，可运行时切换）
- UIKit + SwiftUI 双调试页面（testMode 切换 / 真实-测试 ID 切换 / 实时日志面板 / 复制设备 ID）

## 集成

### 1. 添加 Package 依赖

在 Xcode 中 `File → Add Package Dependencies…`，输入本仓库地址；或直接在 `Package.swift` 中：

```swift
dependencies: [
    .package(path: "../YCAd"),  // 或 .package(url: "你的仓库地址", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "YCAd", package: "YCAd"),
    ])
]
```

### 2. 配置 Info.plist

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>

<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
    <!-- 其他 SKAdNetwork ID -->
</array>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsArbitraryLoadsForMedia</key>
    <true/>
</dict>
```

### 3. 初始化

```swift
import YCAd

// 在 AppDelegate / @main App 启动时
func setupAds() async {
    var config = YCAdConfiguration()
    config.testMode = true              // 开发期强烈建议开启
    config.logLevel = .debug            // 想看更详细日志
    await YCAdCenter.configure(config)
    try? await YCAdCenter.requestConsent(from: nil)
}
```

## 用法

### Banner（SwiftUI）

```swift
YCBannerView(adUnitID: "你的-banner-id")
    .frame(maxWidth: .infinity)
    .frame(height: 60)
```

### Banner（UIKit）

```swift
let ad = YCBannerAd(adUnitID: "你的-banner-id")
try await ad.load(width: view.bounds.width)
let bannerView = ad.makeUIView(in: self)
view.addSubview(bannerView)
// 用 autolayout 布局
```

### Interstitial

```swift
let ad = YCInterstitialAd(adUnitID: "你的-interstitial-id")
try await ad.load()
let result = try await ad.present(from: nil)
if case .dismissed = result {
    print("用户关闭了插屏")
}
```

### Rewarded

```swift
let ad = YCRewardedAd(adUnitID: "你的-rewarded-id")
try await ad.load()
let result = try await ad.present(from: nil)
if case let .rewarded(amount, type) = result {
    print("发放奖励：\(amount) \(type)")
}
```

### App Open（自动监听前后台）

```swift
YCAppOpenAdLifecycleObserver.shared.start(adUnitID: "你的-appopen-id")
// 在 App 进入后台又回前台时会自动展示（冷启动不弹，30s 防抖，4h 过期自动重载）
```

### Native（SwiftUI）

```swift
struct FeedRow: View {
    @StateObject private var ad = YCNativeAd(adUnitID: "你的-native-id")
    var body: some View {
        Group {
            if ad.isReady {
                YCNativeAdView(ad: ad).frame(height: 250)
            } else {
                EmptyView()
            }
        }
        .task { try? await ad.load() }
    }
}
```

## 调试

### UIKit

```swift
present(UINavigationController(rootViewController: YCAdDebugViewController()), animated: true)
```

### SwiftUI

```swift
.sheet(isPresented: $showDebug) {
    NavigationView { YCAdDebugView() }
}
```

调试页面包含 4 个区：

1. **信息**：App ID / SDK 版本 / 设备 ID（可复制）/ 初始化状态 / canRequestAds
2. **配置**：testMode 开关、ID 模式（真实 / 测试）、日志级别
3. **广告加载**：5 种广告类型切换、加载 / 展示按钮、状态显示、Banner / Native 内嵌预览
4. **日志**：实时滚动显示，清空按钮，按级别着色

## 测试 ID 机制

- 内置官方测试 App ID 与 5 种广告的测试 ad unit ID
- `YCAdConfiguration.testMode = true` 时强制使用测试 ID，忽略调用方传入的 ID
- 用户可在 `YCAdConfiguration.testAdUnitIDs[type]` 注册自己的测试 ID，覆盖官方默认
- `markDeviceAsTestDevice = true`（默认）会把当前设备加入 `RequestConfiguration.testDeviceIdentifiers`，即使误用真实 ID 也只返回测试广告，双保险防封号

## 日志

- `YCAdLogger.shared.level`：当前级别（默认 Debug 构建 .info / Release 构建 .none）
- 级别：debug / info / warning / error / none
- 可设 `YCAdLogger.shared.customSink` 接入 OSLog / 文件 / 上报系统
- SDK 内部所有关键动作（load / present / dismiss / 错误 / 配置切换）均打日志
- 调试页面通过 Combine 实时订阅 `YCAdLogger.shared.$entries`

## 架构

- **隔离模型**：所有 public 类型用 `@MainActor final class`（不用 actor）。原因：SDK delegate 已 @MainActor 隔离，且需持有 UIView/VC 等 non-Sendable 类型。
- **全屏广告状态机**：`YCFullScreenAd` 协议 + `YCPresentBox`（实现 `FullScreenContentDelegate`）把回调式 delegate 收敛为 `present(from:) async throws -> YCAdShowResult`，三路径（didFailToPresent / dismiss / reward）通过 `CheckedContinuation` 统一 resume。
- **测试 ID 路由**：`YCAdCenter.resolve(adUnitID:for:)` 在 testMode 时路由到测试 ID。
- **App Open 生命周期**：监听 `UIApplication.didBecomeActiveNotification`，冷启动跳过 + 30s 防抖 + 4h 过期 + 静默降级。

## 许可证

MIT
