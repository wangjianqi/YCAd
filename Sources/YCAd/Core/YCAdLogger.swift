import Foundation
import Combine

/// 日志级别
public enum YCAdLogLevel: Int, Sendable, Comparable {
    case debug   = 0
    case info    = 1
    case warning = 2
    case error   = 3
    case none    = 99

    public static func < (lhs: YCAdLogLevel, rhs: YCAdLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 默认级别：Debug 构建用 .info，Release 用 .none
    public static var defaultLevel: YCAdLogLevel {
        #if DEBUG
        return .info
        #else
        return .none
        #endif
    }

    public var label: String {
        switch self {
        case .debug:   return "DEBUG"
        case .info:    return "INFO"
        case .warning: return "WARN"
        case .error:   return "ERROR"
        case .none:    return "NONE"
        }
    }
}

/// 一条日志
public struct YCAdLogEntry: Sendable, Identifiable {
    public let id: UUID
    public let level: YCAdLogLevel
    public let message: String
    public let time: Date

    public init(level: YCAdLogLevel, message: String, time: Date = Date()) {
        self.id = UUID()
        self.level = level
        self.message = message
        self.time = time
    }
}

/// 全局日志器。@MainActor 隔离；调试页面通过 Combine 订阅 `$entries` 实时展示。
@MainActor
public final class YCAdLogger: ObservableObject {
    public static let shared = YCAdLogger()

    /// 当前级别。低于此级别的日志被丢弃。`.none` 关闭所有日志。
    public var level: YCAdLogLevel = YCAdLogLevel.defaultLevel {
        didSet {
            if level != oldValue {
                let msg = "logLevel \(oldValue.label) -> \(level.label)"
                Self.rawLog(.info, msg)
            }
        }
    }

    /// 内存缓冲上限（默认 500 条）
    public var maxBufferedEntries: Int = 500

    /// 日志缓冲（供调试页面订阅）
    @Published public private(set) var entries: [YCAdLogEntry] = []

    /// 自定义 sink（在 main 上调用，可对接 OSLog / 文件 / 上报系统）
    public var customSink: (@MainActor (YCAdLogEntry) -> Void)?

    private init() {}

    public func clear() {
        entries.removeAll()
    }

    /// 主入口（仅 @MainActor 上下文直接调用）
    public func log(_ level: YCAdLogLevel, _ message: @autoclosure () -> String) {
        guard level >= self.level, level != .none else { return }
        let entry = YCAdLogEntry(level: level, message: message())
        entries.append(entry)
        if entries.count > maxBufferedEntries {
            entries.removeFirst(entries.count - maxBufferedEntries)
        }
        Self.rawLog(level, entry.message)
        customSink?(entry)
    }

    /// 供非 @MainActor 上下文调用：内部 Task hop 到 main。
    nonisolated public static func debug(_ message: @autoclosure () -> String) {
        Task { @MainActor in shared.log(.debug, message()) }
    }
    nonisolated public static func info(_ message: @autoclosure () -> String) {
        Task { @MainActor in shared.log(.info, message()) }
    }
    nonisolated public static func warn(_ message: @autoclosure () -> String) {
        Task { @MainActor in shared.log(.warning, message()) }
    }
    nonisolated public static func error(_ message: @autoclosure () -> String) {
        Task { @MainActor in shared.log(.error, message()) }
    }

    /// 实际写到 os_log / print（不经过 buffer），保证 Release 关闭时也静默。
    nonisolated private static func rawLog(_ level: YCAdLogLevel, _ message: String) {
        #if DEBUG
        print("[YCAd][\(level.label)] \(message)")
        #endif
    }
}
