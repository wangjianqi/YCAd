#if DEBUG
import UIKit

/// 摇一摇调起调试页面（仅 DEBUG 生效）。
///
/// 通过 swizzle `UIResponder.motionEnded(_:with:)` 实现全局监听。
/// 由 `YCAdCenter.enableShakeToDebug` 控制：设为 true 时安装 swizzle，
/// 运行时仍可切换开关（false 时不响应摇动）。
@MainActor
enum YCAdShakeToDebug {

    private static var isInstalled = false
    private static var lastShakeTime: Date = .distantPast

    /// 安装 swizzle（仅一次）。安装后摇动是否响应取决于 `YCAdCenter.enableShakeToDebug`。
    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        let originalSelector = #selector(UIResponder.motionEnded(_:with:))
        let swizzledSelector = #selector(UIResponder.yc_adMotionEnded(_:with:))

        guard let originalMethod = class_getInstanceMethod(UIResponder.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIResponder.self, swizzledSelector) else {
            YCAdLogger.warn("摇一摇 swizzle 安装失败：找不到方法")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        YCAdLogger.info("摇一摇调试已安装（任意页面摇动设备即可打开调试页）")
    }

    /// 摇动事件处理：防抖 + 找顶层 VC + present 调试页。
    static func handleShakeIfNeeded() {
        guard YCAdCenter.enableShakeToDebug else { return }

        // 防抖：2 秒内只响应一次
        let now = Date()
        guard now.timeIntervalSince(lastShakeTime) > 2 else { return }
        lastShakeTime = now

        // 找最顶层 VC 来 present
        guard let top = YCAdInternal.topmostViewController() else {
            YCAdLogger.warn("摇一摇：找不到顶层 ViewController")
            return
        }

        // 避免重复 present
        if let nav = top.presentedViewController as? UINavigationController,
           nav.viewControllers.contains(where: { $0 is YCAdDebugViewController }) { return }
        if top.presentedViewController is YCAdDebugViewController { return }

        let debugVC = YCAdDebugViewController()
        let nav = UINavigationController(rootViewController: debugVC)
        nav.modalPresentationStyle = .formSheet
        top.present(nav, animated: true)
        YCAdLogger.info("摇一摇触发调试页面")
    }
}

extension UIResponder {
    @objc func yc_adMotionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        self.yc_adMotionEnded(motion, with: event)

        if motion == .motionShake {
            YCAdShakeToDebug.handleShakeIfNeeded()
        }
    }
}
#endif
