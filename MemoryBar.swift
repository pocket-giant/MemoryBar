import Cocoa
import ServiceManagement
import SwiftUI
import UserNotifications

private let warnLevel = 90.0
private let critLevel = 95.0
private let notifyKey = "notificationsEnabled"

struct MemorySnapshot {
    let used: UInt64
    let total: UInt64
    var available: UInt64 { total - used }
    var percent: Double { Double(used) / Double(total) * 100 }

    static func read() -> MemorySnapshot? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let total = ProcessInfo.processInfo.physicalMemory
        guard total > 0 else { return nil }
        // App memory + wired + compressed, matching the existing menu bar measure.
        let appPages = max(0, Int64(stats.internal_page_count) - Int64(stats.purgeable_count))
        let usedPages = UInt64(appPages) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        let used = min(total, usedPages * UInt64(vm_kernel_page_size))
        return MemorySnapshot(used: used, total: total)
    }
}

private func colour(for percent: Double) -> NSColor {
    switch percent {
    case ..<80: return .systemGreen
    case ..<85: return .systemYellow
    case ..<90: return .systemOrange
    default: return .systemRed
    }
}

private func sizeText(_ bytes: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
}

final class App: NSObject, NSApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()
    let prefs = DisplayPreferences()
    @Published var snapshot: MemorySnapshot?
    @Published var history: [Double] = []
    @Published var mode: DisplayMode = .percentage {
        didSet { prefs.mode = mode; updateStatus() }
    }
    @Published var percentOnly = false {
        didSet { prefs.percentOnly = percentOnly; updateStatus() }
    }
    @Published var appearance: AppearanceMode = .system {
        didSet { prefs.appearance = appearance; applyAppearance() }
    }
    @Published var notificationsEnabled = false {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: notifyKey) }
    }
    @Published var launchAtLogin = false
    @Published var errorMessage: String?
    private var timer: Timer?
    private var warned = false
    private var alerted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        mode = prefs.mode
        percentOnly = prefs.percentOnly
        appearance = prefs.appearance
        notificationsEnabled = UserDefaults.standard.bool(forKey: notifyKey)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        UNUserNotificationCenter.current().delegate = self

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 328, height: 570)
        popover.contentViewController = NSHostingController(rootView: Dashboard(app: self))
        applyAppearance()
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.toolTip = "MemoryBar — show memory details"
        sample()
        timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate() }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            sample()
            launchAtLogin = SMAppService.mainApp.status == .enabled
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func applyAppearance() {
        let name: NSAppearance.Name?
        switch appearance {
        case .system: name = nil
        case .light: name = .aqua
        case .dark: name = .darkAqua
        }
        popover.appearance = name.flatMap(NSAppearance.init(named:))
    }

    private func updateStatus() {
        guard let percent = snapshot?.percent else {
            item.button?.title = "RAM —"
            return
        }
        item.button?.attributedTitle = NSAttributedString(
            string: menuBarTitle(pct: percent, mode: mode, percentOnly: percentOnly),
            attributes: [.foregroundColor: colour(for: percent),
                         .font: NSFont.systemFont(ofSize: 12, weight: .medium)])
        item.button?.setAccessibilityLabel("Memory used \(Int(percent.rounded())) percent, \(statusLabel(for: percent))")
    }

    private func sample() {
        guard let current = MemorySnapshot.read() else { return }
        snapshot = current
        history.append(current.percent)
        if history.count > 60 { history.removeFirst(history.count - 60) }
        updateStatus()
        checkAlerts(percent: current.percent)
    }

    private func checkAlerts(percent: Double) {
        if percent > critLevel {
            if !alerted { sendNotification("Memory critical", String(format: "%.0f%% of memory in use (over 95%%)", percent)) }
            alerted = true
            warned = true
        } else if percent > warnLevel {
            if !warned { sendNotification("Memory high", String(format: "%.0f%% of memory in use (over 90%%)", percent)) }
            warned = true
            if percent < critLevel - 2 { alerted = false }
        } else if percent < warnLevel - 2 {
            warned = false
            alerted = false
        }
    }

    func setNotifications(_ enabled: Bool) {
        if !enabled { notificationsEnabled = false; return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationsEnabled = granted
                if !granted { self?.errorMessage = "Allow notifications for MemoryBar in System Settings to receive memory alerts." }
            }
        }
    }

    func sendTest() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self?.sendNotification("Memory test", "Notifications are working.", force: true)
                } else {
                    self?.errorMessage = "Allow notifications for MemoryBar in System Settings to send a test alert."
                }
            }
        }
    }

    private func sendNotification(_ title: String, _ body: String, force: Bool = false) {
        guard force || notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .sound])
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled { try service.register() } else { try service.unregister() }
            launchAtLogin = service.status == .enabled
        } catch {
            launchAtLogin = service.status == .enabled
            errorMessage = "Could not change Open at Login. Move MemoryBar to Applications and try again.\n\(error.localizedDescription)"
        }
    }

    func openSite() { NSWorkspace.shared.open(URL(string: "https://pocketgiant.games")!) }
    func quit() { NSApp.terminate(nil) }
}

private struct HistoryGraph: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(1..<4) { index in
                    Path { path in
                        let y = geometry.size.height * CGFloat(index) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }
                if values.count > 1 {
                    Path { path in
                        for (index, value) in values.enumerated() {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(values.count - 1)
                            let y = geometry.size.height * (1 - CGFloat(min(max(value, 0), 100)) / 100)
                            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 40)
        .accessibilityLabel("Memory use over the last five minutes")
        .accessibilityValue(values.isEmpty ? "No readings" : "Latest reading \(Int(values.last!.rounded())) percent")
    }
}

private struct Dashboard: View {
    @ObservedObject var app: App

    private var tint: Color { Color(nsColor: colour(for: app.snapshot?.percent ?? 0)) }
    private var surface: Color { Color(nsColor: .controlBackgroundColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MemoryBar").font(.system(size: 14, weight: .semibold))
                    Text("POCKET GIANT").font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(1.3).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(tint).frame(width: 7, height: 7)
                    .accessibilityLabel("Memory status: \(statusLabel(for: app.snapshot?.percent ?? 0))")
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(app.snapshot.map { String(format: "%.0f%%", $0.percent) } ?? "—")
                        .font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MEMORY USED").font(.system(size: 9, weight: .semibold)).tracking(1.1).foregroundStyle(.secondary)
                        Text(statusLabel(for: app.snapshot?.percent ?? 0)).font(.system(size: 12, weight: .medium))
                    }
                    Spacer()
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.14))
                        Capsule().fill(tint).frame(width: geometry.size.width * CGFloat((app.snapshot?.percent ?? 0) / 100))
                    }
                }
                .frame(height: 7)
                .accessibilityLabel("Memory used")
                .accessibilityValue("\(Int((app.snapshot?.percent ?? 0).rounded())) percent")
                HStack {
                    Text("LAST 5 MINUTES").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    Text("Updates every 5 seconds").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                HistoryGraph(values: app.history, tint: tint)
            }
            .padding(12)
            .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))

            HStack(spacing: 8) {
                metric("USED", app.snapshot.map { sizeText($0.used) } ?? "—")
                metric("AVAILABLE", app.snapshot.map { sizeText($0.available) } ?? "—")
            }
            Text("Used includes app, wired and compressed memory. Available is the remainder of physical RAM.")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Menu bar").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Picker("Menu bar", selection: $app.mode) {
                        Text("Percentage").tag(DisplayMode.percentage)
                        Text("Status").tag(DisplayMode.status)
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 171)
                }
                Toggle("Show percentage only", isOn: $app.percentOnly)
                    .disabled(app.mode == .status)
                HStack {
                    Text("Appearance").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Picker("Appearance", selection: $app.appearance) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                    }
                    .labelsHidden().frame(width: 125)
                }
                Toggle("Memory alerts", isOn: Binding(get: { app.notificationsEnabled }, set: app.setNotifications))
                Toggle("Open at Login", isOn: Binding(get: { app.launchAtLogin }, set: app.setLaunchAtLogin))
            }
            .font(.system(size: 11))
            .toggleStyle(.switch)
            .controlSize(.small)

            Divider()
            HStack {
                Button("Made by Pocket Giant") { app.openSite() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Send Test Notification") { app.sendTest() }
                    Button("Visit Pocket Giant") { app.openSite() }
                    Divider()
                    Button("Quit MemoryBar") { app.quit() }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 16))
                }
                .menuStyle(.borderlessButton).frame(width: 25)
                .accessibilityLabel("More options")
            }
            .font(.system(size: 10))
        }
        .padding(16)
        .frame(width: 328)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("MemoryBar", isPresented: Binding(get: { app.errorMessage != nil }, set: { if !$0 { app.errorMessage = nil } })) {
            Button("OK", role: .cancel) { app.errorMessage = nil }
        } message: { Text(app.errorMessage ?? "") }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = App()
        app.delegate = delegate
        app.run()
    }
}
