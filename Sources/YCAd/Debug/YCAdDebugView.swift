import SwiftUI
import UIKit
import Combine

/// SwiftUI 版 YCAd 调试页面。
///
/// 用法：
/// ```swift
/// .sheet(isPresented: $showDebug) {
///     NavigationView { YCAdDebugView() }
/// }
/// ```
public struct YCAdDebugView: View {

    @StateObject private var vm = YCAdDebugViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        Form {
            infoSection
            configSection
            adSection
            logSection
        }
        .navigationTitle("YCAd Debug")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") { dismiss() }
            }
        }
    }

    // MARK: - 1. 信息

    private var infoSection: some View {
        Section("信息") {
            row("App ID", value: vm.appID)
            row("SDK 版本", value: vm.sdkVersion)
            row("已初始化", value: vm.isInitialized ? "是" : "否")
            row("canRequestAds", value: vm.canRequestAds ? "是" : "否")
            HStack {
                Text("设备 ID")
                Spacer()
                Text(vm.deviceID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("复制设备 ID") {
                UIPasteboard.general.string = vm.deviceID
            }
        }
    }

    // MARK: - 2. 配置

    private var configSection: some View {
        Section("配置") {
            Toggle("testMode（测试模式）", isOn: $vm.testMode)
                .onChange(of: vm.testMode) { _, newValue in
                    YCAdCenter.configuration.testMode = newValue
                }

            Picker("ID 模式", selection: $vm.idMode) {
                Text("测试 ID").tag(YCAdDebugViewModel.IDMode.test)
                Text("真实 ID").tag(YCAdDebugViewModel.IDMode.real)
            }
            .pickerStyle(.segmented)
            .disabled(vm.testMode)
            if vm.testMode {
                Text("testMode 开启时强制使用测试 ID，ID 模式被禁用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Picker("日志级别", selection: $vm.logLevel) {
                Text("debug").tag(YCAdLogLevel.debug)
                Text("info").tag(YCAdLogLevel.info)
                Text("warning").tag(YCAdLogLevel.warning)
                Text("error").tag(YCAdLogLevel.error)
                Text("none").tag(YCAdLogLevel.none)
            }
            .onChange(of: vm.logLevel) { _, newValue in
                YCAdLogger.shared.level = newValue
            }
        }
    }

    // MARK: - 3. 广告加载

    private var adSection: some View {
        Section("广告加载") {
            Picker("广告类型", selection: $vm.adType) {
                ForEach(YCAdType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if !vm.testMode && vm.idMode == .real {
                TextField("adUnitID", text: $vm.adUnitID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                row("当前 ID", value: vm.currentAdUnitID)
            }

            HStack {
                Button("加载") { vm.load() }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLoading)
                Button("展示") { vm.present() }
                    .buttonStyle(.bordered)
                    .disabled(!vm.canPresent)
            }
            if let status = vm.statusText {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if vm.adType == .banner, vm.bannerReady {
                YCBannerView(adUnitID: vm.effectiveAdUnitID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            if vm.adType == .native, vm.nativeReady {
                YCNativeAdView(ad: vm.nativeAd)
                    .frame(height: 250)
            }
        }
    }

    // MARK: - 4. 日志

    private var logSection: some View {
        Section("日志") {
            HStack {
                Button("清空") { YCAdLogger.shared.clear() }
                Spacer()
                Text("\(vm.logEntries.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ForEach(vm.logEntries.suffix(200)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.level.label)
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 4)
                            .background(levelColor(entry.level).opacity(0.15))
                            .foregroundColor(levelColor(entry.level))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        Text(timeString(entry.time))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(entry.message)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func levelColor(_ level: YCAdLogLevel) -> Color {
        switch level {
        case .debug:   return .gray
        case .info:    return .blue
        case .warning: return .orange
        case .error:   return .red
        case .none:    return .gray
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
final class YCAdDebugViewModel: ObservableObject {

    enum IDMode: Hashable { case test, real }

    @Published var appID: String = ""
    @Published var sdkVersion: String = ""
    @Published var isInitialized: Bool = false
    @Published var canRequestAds: Bool = false
    @Published var deviceID: String = ""
    @Published var testMode: Bool = false
    @Published var idMode: IDMode = .test
    @Published var logLevel: YCAdLogLevel = .info
    @Published var adType: YCAdType = .interstitial
    @Published var adUnitID: String = ""
    @Published var isLoading: Bool = false
    @Published var canPresent: Bool = false
    @Published var statusText: String?
    @Published var logEntries: [YCAdLogEntry] = []
    @Published var bannerReady: Bool = false
    @Published var nativeReady: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var bannerAd: YCBannerAd?
    private var interstitialAd: YCInterstitialAd?
    private var rewardedAd: YCRewardedAd?
    private var appOpenAd: YCAppOpenAd?
    private(set) var nativeAd: YCNativeAd = YCNativeAd(adUnitID: "")

    var currentAdUnitID: String {
        let type = adType
        if YCAdCenter.configuration.testMode {
            return YCAdInternal.currentTestAdUnitID(for: type)
        }
        if idMode == .test {
            return YCAdInternal.officialTestAdUnitIDs[type] ?? ""
        }
        return adUnitID
    }

    var effectiveAdUnitID: String { currentAdUnitID }

    init() {
        refresh()
        // 订阅日志
        YCAdLogger.shared.$entries
            .receive(on: RunLoop.main)
            .sink { [weak self] entries in
                self?.logEntries = entries
            }
            .store(in: &cancellables)
    }

    func refresh() {
        appID = YCAdCenter.appID
        sdkVersion = YCAdCenter.sdkVersion
        isInitialized = YCAdCenter.isInitialized
        canRequestAds = YCAdCenter.canRequestAds
        deviceID = YCAdCenter.deviceID
        testMode = YCAdCenter.configuration.testMode
        logLevel = YCAdLogger.shared.level
    }

    func load() {
        Task {
            isLoading = true
            statusText = nil
            defer { isLoading = false; refresh() }
            let id = currentAdUnitID
            do {
                switch adType {
                case .banner:
                    let ad = YCBannerAd(adUnitID: id)
                    self.bannerAd = ad
                    try await ad.load(width: UIScreen.main.bounds.width)
                    bannerReady = true
                    canPresent = false
                    statusText = "Banner 加载成功"
                case .interstitial:
                    let ad = YCInterstitialAd(adUnitID: id)
                    self.interstitialAd = ad
                    try await ad.load()
                    canPresent = true
                    statusText = "Interstitial 加载成功"
                case .rewarded:
                    let ad = YCRewardedAd(adUnitID: id)
                    self.rewardedAd = ad
                    try await ad.load()
                    canPresent = true
                    statusText = "Rewarded 加载成功"
                case .appOpen:
                    let ad = YCAppOpenAd(adUnitID: id)
                    self.appOpenAd = ad
                    try await ad.load()
                    canPresent = true
                    statusText = "AppOpen 加载成功"
                case .native:
                    nativeAd = YCNativeAd(adUnitID: id)
                    try await nativeAd.load()
                    nativeReady = true
                    canPresent = false
                    statusText = "Native 加载成功"
                }
            } catch {
                statusText = "失败: \(error.localizedDescription)"
                canPresent = false
            }
        }
    }

    func present() {
        Task {
            do {
                switch adType {
                case .interstitial:
                    let r = try await interstitialAd?.present(from: nil) ?? .dismissed
                    statusText = "Interstitial 结果: \(r)"
                    canPresent = false
                case .rewarded:
                    let r = try await rewardedAd?.present(from: nil) ?? .dismissed
                    statusText = "Rewarded 结果: \(r)"
                    canPresent = false
                case .appOpen:
                    let r = try await appOpenAd?.present(from: nil) ?? .dismissed
                    statusText = "AppOpen 结果: \(r)"
                    canPresent = false
                default:
                    break
                }
            } catch {
                statusText = "展示失败: \(error.localizedDescription)"
            }
        }
    }
}
