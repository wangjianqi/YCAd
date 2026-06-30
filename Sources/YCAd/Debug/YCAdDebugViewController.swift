import UIKit
import SwiftUI
import Combine

/// UIKit 版 YCAd 调试页面。
///
/// 用法：
/// ```swift
/// let vc = YCAdDebugViewController()
/// navigationController?.pushViewController(vc, animated: true)
/// // 或
/// present(UINavigationController(rootViewController: vc), animated: true)
/// ```
@MainActor
public final class YCAdDebugViewController: UIViewController {

    private let vm = YCAdDebugViewModel()
    private var tableView: UITableView!
    private var cancellables = Set<AnyCancellable>()
    private var bannerContainer: UIView?

    private enum Section: Int, CaseIterable {
        case info, config, ad, log
    }

    public init() { super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "YCAd Debug"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(onClose)
        )

        setupTableView()
        bindViewModel()
    }

    @objc private func onClose() {
        dismiss(animated: true)
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "switch")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "segment")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "input")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "button")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "log")
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func bindViewModel() {
        vm.$logEntries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tableView.reloadSections(IndexSet(integer: Section.log.rawValue), with: .none) }
            .store(in: &cancellables)

        vm.$statusText
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tableView.reloadSections(IndexSet(integer: Section.ad.rawValue), with: .none) }
            .store(in: &cancellables)

        vm.$bannerReady
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tableView.reloadSections(IndexSet(integer: Section.ad.rawValue), with: .none) }
            .store(in: &cancellables)

        vm.$nativeReady
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tableView.reloadSections(IndexSet(integer: Section.ad.rawValue), with: .none) }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func onToggleTestMode(_ sw: UISwitch) {
        vm.testMode = sw.isOn
        YCAdCenter.configuration.testMode = sw.isOn
        tableView.reloadSections(IndexSet(integer: Section.config.rawValue), with: .none)
        tableView.reloadSections(IndexSet(integer: Section.ad.rawValue), with: .none)
    }

    @objc private func onToggleAdsDisabled(_ sw: UISwitch) {
        vm.adsDisabled = sw.isOn
        YCAdCenter.adsDisabled = sw.isOn
    }

    @objc private func onSegmentIDMode(_ seg: UISegmentedControl) {
        vm.idMode = seg.selectedSegmentIndex == 0 ? .test : .real
        tableView.reloadSections(IndexSet(integer: Section.ad.rawValue), with: .none)
    }

    @objc private func onSegmentAdType(_ seg: UISegmentedControl) {
        let all = YCAdType.allCases
        if seg.selectedSegmentIndex < all.count {
            vm.adType = all[seg.selectedSegmentIndex]
            vm.canPresent = false
            vm.statusText = nil
            tableView.reloadSections(IndexSet(integer: Section.ad.rawValue), with: .none)
        }
    }

    @objc private func onLoad() { vm.load() }
    @objc private func onPresent() { vm.present() }
    @objc private func onCopyDeviceID() {
        UIPasteboard.general.string = vm.deviceID
        let alert = UIAlertController(title: nil, message: "已复制设备 ID", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
    @objc private func onClearLog() {
        YCAdLogger.shared.clear()
    }

    @objc private func onAdUnitIDChanged(_ tf: UITextField) {
        vm.adUnitID = tf.text ?? ""
    }
}

// MARK: - UITableView Data Source

extension YCAdDebugViewController: UITableViewDataSource, UITableViewDelegate {

    public func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .info:   return "信息"
        case .config: return "配置"
        case .ad:     return "广告加载"
        case .log:    return "日志"
        case .none:   return nil
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .info:   return 6
        case .config: return vm.testMode ? 5 : 4
        case .ad:     return adRowCount
        case .log:    return 1 + min(vm.logEntries.count, 200)
        case .none:   return 0
        }
    }

    private var adRowCount: Int {
        var n = 4   // 类型 / ID / 加载展示 / 状态
        if vm.adType == .banner && vm.bannerReady { n += 1 }
        if vm.adType == .native && vm.nativeReady { n += 1 }
        return n
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .info:   return infoCell(row: indexPath.row)
        case .config: return configCell(row: indexPath.row)
        case .ad:     return adCell(row: indexPath.row)
        case .log:    return logCell(row: indexPath.row)
        case .none:   return UITableViewCell()
        }
    }

    // MARK: Info Cells

    private func infoCell(row: Int) -> UITableViewCell {
        switch row {
        case 0: return makeKeyValueCell("App ID", vm.appID)
        case 1: return makeKeyValueCell("SDK 版本", vm.sdkVersion)
        case 2: return makeKeyValueCell("已初始化", vm.isInitialized ? "是" : "否")
        case 3: return makeKeyValueCell("canRequestAds", vm.canRequestAds ? "是" : "否")
        case 4: return makeKeyValueCell("设备 ID", vm.deviceID)
        case 5:
            let cell = tableView.dequeueReusableCell(withIdentifier: "button", for: IndexPath(row: row, section: Section.info.rawValue))
            cell.textLabel?.text = "复制设备 ID"
            cell.textLabel?.textColor = .systemBlue
            cell.accessoryType = .none
            cell.selectionStyle = .default
            return cell
        default: return UITableViewCell()
        }
    }

    // MARK: Config Cells

    private func configCell(row: Int) -> UITableViewCell {
        switch row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: IndexPath(row: row, section: Section.config.rawValue))
            cell.textLabel?.text = "关闭所有广告（紧急刹车）"
            cell.textLabel?.textColor = .systemRed
            let sw = UISwitch()
            sw.isOn = vm.adsDisabled
            sw.onTintColor = .systemRed
            sw.addTarget(self, action: #selector(onToggleAdsDisabled), for: .valueChanged)
            cell.accessoryView = sw
            cell.selectionStyle = .none
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: IndexPath(row: row, section: Section.config.rawValue))
            cell.textLabel?.text = "testMode（测试模式）"
            let sw = UISwitch()
            sw.isOn = vm.testMode
            sw.addTarget(self, action: #selector(onToggleTestMode), for: .valueChanged)
            cell.accessoryView = sw
            cell.selectionStyle = .none
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: IndexPath(row: row, section: Section.config.rawValue))
            cell.textLabel?.text = "ID 模式"
            let seg = UISegmentedControl(items: ["测试 ID", "真实 ID"])
            seg.selectedSegmentIndex = vm.idMode == .test ? 0 : 1
            seg.addTarget(self, action: #selector(onSegmentIDMode), for: .valueChanged)
            seg.isEnabled = !vm.testMode
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell
        case 3:
            if vm.testMode {
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: IndexPath(row: row, section: Section.config.rawValue))
                cell.textLabel?.text = "testMode 开启时强制使用测试 ID"
                cell.textLabel?.font = .systemFont(ofSize: 12)
                cell.textLabel?.textColor = .secondaryLabel
                cell.selectionStyle = .none
                return cell
            } else {
                return logLevelCell(row: row)
            }
        case 4:
            return logLevelCell(row: row)
        default: return UITableViewCell()
        }
    }

    private func logLevelCell(row: Int) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: IndexPath(row: row, section: Section.config.rawValue))
        cell.textLabel?.text = "日志级别"
        let seg = UISegmentedControl(items: ["debug", "info", "warn", "error", "none"])
        switch vm.logLevel {
        case .debug: seg.selectedSegmentIndex = 0
        case .info: seg.selectedSegmentIndex = 1
        case .warning: seg.selectedSegmentIndex = 2
        case .error: seg.selectedSegmentIndex = 3
        case .none: seg.selectedSegmentIndex = 4
        @unknown default: seg.selectedSegmentIndex = 1
        }
        seg.addTarget(self, action: #selector(onSegmentLogLevel(_:)), for: .valueChanged)
        cell.accessoryView = seg
        cell.selectionStyle = .none
        return cell
    }

    @objc private func onSegmentLogLevel(_ seg: UISegmentedControl) {
        let levels: [YCAdLogLevel] = [.debug, .info, .warning, .error, .none]
        if seg.selectedSegmentIndex < levels.count {
            vm.logLevel = levels[seg.selectedSegmentIndex]
            YCAdLogger.shared.level = vm.logLevel
        }
    }

    // MARK: Ad Cells

    private func adCell(row: Int) -> UITableViewCell {
        switch row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: IndexPath(row: row, section: Section.ad.rawValue))
            cell.textLabel?.text = "广告类型"
            let seg = UISegmentedControl(items: YCAdType.allCases.map { $0.rawValue })
            if let idx = YCAdType.allCases.firstIndex(of: vm.adType) {
                seg.selectedSegmentIndex = idx
            }
            seg.addTarget(self, action: #selector(onSegmentAdType), for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell
        case 1:
            if !vm.testMode && vm.idMode == .real {
                let cell = tableView.dequeueReusableCell(withIdentifier: "input", for: IndexPath(row: row, section: Section.ad.rawValue))
                cell.textLabel?.text = "adUnitID"
                let tf = UITextField(frame: CGRect(x: 100, y: 8, width: cell.contentView.bounds.width - 120, height: 30))
                tf.placeholder = "输入 adUnitID"
                tf.text = vm.adUnitID
                tf.addTarget(self, action: #selector(onAdUnitIDChanged), for: .editingChanged)
                cell.contentView.addSubview(tf)
                cell.selectionStyle = .none
                return cell
            } else {
                return makeKeyValueCell("当前 ID", vm.currentAdUnitID)
            }
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "button", for: IndexPath(row: row, section: Section.ad.rawValue))
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 12
            let loadBtn = UIButton(type: .system)
            loadBtn.setTitle("加载", for: .normal)
            loadBtn.isEnabled = !vm.isLoading
            loadBtn.addTarget(self, action: #selector(onLoad), for: .touchUpInside)
            let presentBtn = UIButton(type: .system)
            presentBtn.setTitle("展示", for: .normal)
            presentBtn.isEnabled = vm.canPresent
            presentBtn.addTarget(self, action: #selector(onPresent), for: .touchUpInside)
            stack.addArrangedSubview(loadBtn)
            stack.addArrangedSubview(presentBtn)
            stack.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            ])
            cell.selectionStyle = .none
            return cell
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: IndexPath(row: row, section: Section.ad.rawValue))
            cell.textLabel?.text = vm.statusText ?? "（未操作）"
            cell.textLabel?.font = .systemFont(ofSize: 12)
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textColor = .secondaryLabel
            cell.selectionStyle = .none
            return cell
        case 4:
            // banner 或 native 预览
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: IndexPath(row: row, section: Section.ad.rawValue))
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            if vm.adType == .banner {
                let bannerHost = UIHostingController(rootView: YCBannerView(adUnitID: vm.effectiveAdUnitID).frame(height: 60))
                addChild(bannerHost)
                bannerHost.view.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(bannerHost.view)
                NSLayoutConstraint.activate([
                    bannerHost.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                    bannerHost.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                    bannerHost.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                    bannerHost.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                    bannerHost.view.heightAnchor.constraint(equalToConstant: 60),
                ])
                bannerHost.didMove(toParent: self)
            } else if vm.adType == .native {
                let nativeHost = UIHostingController(rootView: YCNativeAdView(ad: vm.nativeAd).frame(height: 250))
                addChild(nativeHost)
                nativeHost.view.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(nativeHost.view)
                NSLayoutConstraint.activate([
                    nativeHost.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                    nativeHost.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                    nativeHost.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                    nativeHost.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                    nativeHost.view.heightAnchor.constraint(equalToConstant: 250),
                ])
                nativeHost.didMove(toParent: self)
            }
            cell.selectionStyle = .none
            return cell
        default: return UITableViewCell()
        }
    }

    // MARK: Log Cells

    private func logCell(row: Int) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "log", for: IndexPath(row: row, section: Section.log.rawValue))
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .systemFont(ofSize: 11)
        if row == 0 {
            cell.textLabel?.text = "清空日志（共 \(vm.logEntries.count) 条）"
            cell.textLabel?.textColor = .systemBlue
            cell.accessoryType = .none
            cell.selectionStyle = .default
            return cell
        }
        let entry = vm.logEntries[vm.logEntries.count - min(vm.logEntries.count, 200) + row - 1]
        let timeStr = logTimeFormatter.string(from: entry.time)
        cell.textLabel?.text = "[\(entry.level.label)] \(timeStr)\n\(entry.message)"
        switch entry.level {
        case .debug:   cell.textLabel?.textColor = .secondaryLabel
        case .info:    cell.textLabel?.textColor = .label
        case .warning: cell.textLabel?.textColor = .systemOrange
        case .error:   cell.textLabel?.textColor = .systemRed
        case .none:    cell.textLabel?.textColor = .secondaryLabel
        }
        cell.selectionStyle = .none
        return cell
    }

    private var logTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .info where indexPath.row == 5: onCopyDeviceID()
        case .log where indexPath.row == 0: onClearLog()
        default: break
        }
    }

    // MARK: Helper

    private func makeKeyValueCell(_ key: String, _ value: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: IndexPath())
        var content = cell.defaultContentConfiguration()
        content.text = key
        content.secondaryText = value
        content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 1
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
}
