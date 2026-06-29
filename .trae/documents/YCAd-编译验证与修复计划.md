# YCAd - 编译验证与修复计划

## Context（背景）

YCAd 是基于 AdMob 的 Swift Package 广告封装库，目标是让用户的其他 iOS 项目通过 SPM 一行依赖即可集成，避免每次重复封装。需求包含：5 种广告类型（Banner / Interstitial / Rewarded / App Open / Native）、UIKit + SwiftUI 双层 API、可配置测试 ID（appID + 广告单元 ID）、可开关的调试日志（Debug 默认开 / Release 默认关）、UIKit + SwiftUI 双版本调试页面（支持真实 / 测试广告加载切换、实时日志面板、复制设备 ID）。

在上一段会话中，已按计划文档 `.trae/documents/YCAd-AdMob封装库实现计划.md` 完成全部代码实现：
- `Package.swift`（Swift 6、iOS 17.6、依赖 GoogleMobileAds v13 + UMP v3）
- 19 个源文件（Core / Banner / Interstitial / Rewarded / AppOpen / Native / Debug 全部就位）
- `README.md` 集成文档
- `Tests/YCAdTests/YCAdTests.swift` 覆盖类型/日志/错误/ID 路由/状态机/配置单测

当前处于 Plan Mode 重启状态，需要重新制定一份聚焦于"编译验证 + 修复"的计划，因为唯一剩下的工作就是 `swift build` / `swift test` 验证与修复任何编译/测试错误。

---

## Current State Analysis（当前状态）

### 已完成（无需再动）

通过 Glob 与 Read 验证，以下文件都已存在且内容完整：

- [Package.swift](file:///Users/WJQ/ai_opensource/YCAd/Package.swift) — swift-tools-version 6.0、platforms `.iOS("17.6")`、依赖 GoogleMobileAds v13 + UMP v3、`swiftLanguageVersions: [.v6]`
- [Sources/YCAd/Core/YCAdTypes.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Core/YCAdTypes.swift) — YCAdType / YCAdSize / YCAdState / YCAdShowResult / YCAdContentRating
- [Sources/YCAd/Core/YCAdError.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Core/YCAdError.swift) — 错误枚举 + NSError(domain: "com.google.admob") 映射 + LocalizedError
- [Sources/YCAd/Core/YCAdLogger.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Core/YCAdLogger.swift) — @MainActor ObservableObject，@Published entries，nonisolated 静态方法
- [Sources/YCAd/Core/YCAdConfiguration.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Core/YCAdConfiguration.swift) — testMode / testAdUnitIDs / markDeviceAsTestDevice / tagForUnderAge / maxAdContentRating / logLevel
- [Sources/YCAd/Core/YCAdInternal.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Core/YCAdInternal.swift) — officialTestAppID / officialTestAdUnitIDs / currentTestAdUnitID(for:) / readAppIDFromInfoPlist / deviceID / topmostViewController
- [Sources/YCAd/Core/YCAdCenter.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Core/YCAdCenter.swift) — configure / requestConsent / resolve / applyRequestConfiguration / applyConfigurationSideEffects
- [Sources/YCAd/Core/YCFullScreenAdController.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Core/YCFullScreenAdController.swift) — YCPresentBox（FullScreenContentDelegate → continuation）+ YCFullScreenAd 协议
- [Sources/YCAd/Banner/YCBannerAd.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Banner/YCBannerAd.swift) + [YCBannerView.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Banner/YCBannerView.swift)
- [Sources/YCAd/Interstitial/YCInterstitialAd.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Interstitial/YCInterstitialAd.swift)
- [Sources/YCAd/Rewarded/YCRewardedAd.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Rewarded/YCRewardedAd.swift) — 包含 YCRewardInfo
- [Sources/YCAd/AppOpen/YCAppOpenAd.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/AppOpen/YCAppOpenAd.swift) + [YCAppOpenAdLifecycleObserver.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/AppOpen/YCAppOpenAdLifecycleObserver.swift)
- [Sources/YCAd/Native/YCNativeAd.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Native/YCNativeAd.swift) + [YCNativeAdLoader.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Native/YCNativeAdLoader.swift) + [YCNativeAdView.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Native/YCNativeAdView.swift)
- [Sources/YCAd/Debug/YCAdDebugView.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Debug/YCAdDebugView.swift) + [YCAdDebugViewController.swift](file:///Users/WJQ/ai_opensource/YCAd/Sources/YCAd/Debug/YCAdDebugViewController.swift)
- [README.md](file:///Users/WJQ/ai_opensource/YCAd/README.md)
- [Tests/YCAdTests/YCAdTests.swift](file:///Users/WJQ/ai_opensource/YCAd/Tests/YCAdTests/YCAdTests.swift) — 覆盖 YCAdType / YCAdLogLevel / YCAdLogger（level 过滤/clear/maxBufferedEntries）/ YCAdError（NSError 映射/wrap/localizedDescription）/ YCAdCenter.resolve（testMode 开/关/用户自定义覆盖）/ YCAdInternal.currentTestAdUnitID / YCAdState / YCAdConfiguration

### 待完成

- **Task 9 — 编译验证**：在 `/Users/WJQ/ai_opensource/YCAd` 下运行 `swift build`，验证 SPM 能拉取 GoogleMobileAds v13.x + UMP v3 并编译通过。如有编译错误，逐个修复。
- **Task 10 — 单测验证**：运行 `swift test`，验证上述单测全部通过（不依赖网络与真实 SDK 状态）。如有失败，修复。
- **Task 11 — 完工回报**：向用户汇报库已可用、集成方式、调试页面调起方式、已通过编译与单测。

---

## Proposed Changes（实施方案）

### 步骤 1：执行 `swift build` 编译

在 `/Users/WJQ/ai_opensource/YCAd` 下运行：

```bash
swift build 2>&1
```

SPM 会自动拉取 `swift-package-manager-google-mobile-ads` v13.x 与 `swift-package-manager-google-user-messaging-platform` v3.x 到 `.build/`，然后编译 `YCAd` target。

**预期可能出现的编译风险点**（基于 v13.x 的 breaking changes 与 Swift 6 严格并发）：

1. **FullScreenContentDelegate 方法签名**：v13 中 delegate 方法可能不再以 `nonisolated` 标注，或参数类型从 `AnyObject` 变为具体的广告类型（如 `InterstitialAd`）。若编译报"方法未实现 protocol 要求"，需调整 `YCPresentBox` 的方法签名以匹配 v13 实际签名。
2. **@MainActor 隔离冲突**：`nonisolated func ad(_:didFailToPresentContentWithError:)` 内部访问 `self.cont` 等 @MainActor 隔离属性时，应通过 `Task { @MainActor in ... }` hop（已这样写）。若编译报"actor-isolated property can not be referenced"，需确认 Task hop 正确。
3. **MobileAds.shared.start() 签名**：v13 升级为 `async -> InitializationStatus`，已用 `await` 调用。若 SDK 版本实际签名不同（如返回 `Void`），需调整。
4. **Banner 尺寸 API**：v13 用 `largeAnchoredAdaptiveBanner(width:)`。若该方法在最新 v13.x 中签名变化或被进一步重命名，需调整 `YCAdSize.resolve(width:)`。
5. **InterstitialAd.load / RewardedAd.load / AppOpenAd.load 的 async 化**：v13 升级为 `async throws`。若 SDK 实际仍是 completion handler 形式，需用 `withCheckedThrowingContinuation` 包装。
6. **AdSize / AdRequest 等类型名**：v13 去掉 GAD 前缀，已按新名（`AdSize` / `Request` / `BannerView` / `InterstitialAd` / `RewardedAd` / `AppOpenAd` / `AdLoader` / `NativeAd` / `NativeAdView`）使用。若有偏差，按编译报错修正。
7. **Package.swift 中 platforms 字符串字面量**：`.iOS("17.6")` 在 swift-tools-version 6.0 下应可解析。若报错，退化为 `.iOS(.v17)` 或上调 swift-tools-version。
8. **Swift 6 数据竞争**：若编译报 "capture of 'x' with non-sendable type '...' in a `@Sendable` closure"，需为相关类型加 `Sendable` 或调整为 @MainActor 隔离。

**修复策略**：每次 `swift build` 输出后，逐个定位错误（看 file:line），用 Edit 工具最小化修复，然后重跑 `swift build`。迭代直到编译通过。每次修复都要确认不破坏已通过的测试。

### 步骤 2：执行 `swift test` 单测

编译通过后运行：

```bash
swift test 2>&1
```

**预期可能出现的测试失败**：

1. **YCAdLogger 单测相互污染**：多个测试都用 `YCAdLogger.shared` 单例，level/maxBufferedEntries 可能跨测试泄漏。已有 `defer { ... }` 恢复，但若执行顺序导致 level 残留，可能影响后续测试。需保证每个测试在开头显式设置自己需要的 level。
2. **YCAdCenter.configuration 静态属性全局污染**：已有 `defer { YCAdCenter.configuration = original }` 恢复。若失败，检查是否 didSet 副作用导致 logger.level 被改。
3. **@MainActor 测试标注**：所有访问 `YCAdLogger.shared` / `YCAdCenter.configuration` 的测试方法已加 `@MainActor`。若有遗漏，编译会报错。

**修复策略**：定位失败测试，分析是测试本身的问题还是被测代码的问题，针对性修复。优先修复被测代码；若测试预期本身错了（如对 SDK 行为的错误假设），修正测试。

### 步骤 3：完工回报

向用户报告：
- 库已可用，路径 `/Users/WJQ/ai_opensource/YCAd`
- 集成方式：在其他项目的 `Package.swift` 加 `.package(path: "/Users/WJQ/ai_opensource/YCAd")` 或 git URL 依赖，target 加 `"YCAd"` 依赖
- 调试页面调起：`present(YCAdDebugViewController(), animated: true)`（UIKit）或 SwiftUI `YCAdDebugView()`
- 测试 ID 机制：`config.testMode = true` 自动用官方测试 ID；可在 `config.testAdUnitIDs[.banner] = "..."` 覆盖
- 日志：`config.logLevel = .debug/.info/.warning/.error/.none`，默认 Debug 构建开 / Release 关
- 编译与单测结果

---

## Assumptions & Decisions（假设与决策）

1. **不再重新设计架构**：上一段会话已经过用户批准的计划文档 `.trae/documents/YCAd-AdMob封装库实现计划.md` 完成实现。本计划只做验证与修复，不重新讨论架构决策（@MainActor final class、YCPresentBox + CheckedContinuation、测试 ID 路由等）。
2. **不在沙箱内验证真实广告加载**：真实 SDK 状态与网络依赖无法在沙箱内验证，由用户在示例 App 工程验证（已在 README 中说明步骤）。
3. **保留所有现有代码**：除非编译/测试报错，不主动重构现有实现。修复以"最小化改动、让编译/测试通过"为目标。
4. **若 `swift build` 因网络拉不到 SPM 依赖失败**：这是环境问题而非代码问题，会明确告知用户在能联网的环境运行；如确有需要，可尝试用 `dangerouslyDisableSandbox: true` 重跑（沙箱默认禁网）。
5. **使用 TaskCreate 跟踪**：实施时会创建 Task 9/10/11 三个 todo 跟踪进度。
6. **修复迭代上限**：若单轮 `swift build` 报错超过 ~20 个，先看是否是根因（如 SDK 版本不匹配），避免逐个修；若是根因，可能需要调整 Package.swift 的 `from:` 版本号。

---

## Verification Steps（验证步骤）

1. **编译验证**：
   ```bash
   cd /Users/WJQ/ai_opensource/YCAd && swift build 2>&1
   ```
   成功标志：`Building for debugging...` → `[4/4] Build complete!`，无 error。

2. **单测验证**：
   ```bash
   cd /Users/WJQ/ai_opensource/YCAd && swift test 2>&1
   ```
   成功标志：所有 Test Suite 全部 passed，`Executed N tests, with 0 failures`。

3. **完工回报**：向用户输出最终状态与集成指引。
