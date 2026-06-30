import Foundation

/// YCAd 统一错误类型
public enum YCAdError: Error, Sendable, Equatable {
    /// 广告未就绪（未 load 完成）
    case notReady
    /// 广告已过期（如 App Open 4 小时未展示）
    case expired
    /// 广告已被全局禁用（调试页面"一键关闭所有广告"开关）
    case disabled
    /// 广告单元 ID 不合法
    case invalidAdUnitID
    /// 同意流程未完成，无法请求广告
    case consentRequired
    /// load 失败
    case loadFailed(code: Int, message: String)
    /// present 失败
    case presentFailed(code: Int, message: String)
    /// 已有广告正在加载或展示
    case busy
}

extension YCAdError {
    /// 把 SDK 抛出的 NSError 映射为 YCAdError。
    /// AdMob 错误 domain 为 "com.google.admob" 或 "com.google.mobileads"。
    init(_ nsError: NSError) {
        let domain = nsError.domain
        let isAdMob = domain == "com.google.admob" || domain == "com.google.mobileads"
        let code = nsError.code
        let message = nsError.localizedDescription

        if !isAdMob {
            self = .loadFailed(code: code, message: message)
            return
        }

        switch code {
        case 0:  self = .notReady
        case 1:  self = .invalidAdUnitID
        case 7:  self = .notReady       // 网络无响应，归类为未就绪
        case 8:  self = .notReady       // 无填充
        case 9:  self = .expired        // 广告过期
        default: self = .loadFailed(code: code, message: message)
        }
    }

    /// 把任意 Error 映射为 YCAdError
    public static func wrap(_ error: Error) -> YCAdError {
        if let ycerr = error as? YCAdError { return ycerr }
        let nserr = error as NSError
        return YCAdError(nserr)
    }
}

extension YCAdError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notReady:            return "广告未就绪"
        case .expired:             return "广告已过期"
        case .disabled:            return "广告已被全局禁用"
        case .invalidAdUnitID:     return "广告单元 ID 不合法"
        case .consentRequired:     return "需要先完成 UMP 同意流程"
        case .busy:                return "已有广告正在加载或展示"
        case let .loadFailed(code, msg):    return "广告加载失败 [\(code)]: \(msg)"
        case let .presentFailed(code, msg): return "广告展示失败 [\(code)]: \(msg)"
        }
    }
}
