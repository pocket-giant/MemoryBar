import Cocoa
import ServiceManagement
import UserNotifications

// Menu bar memory-used %, colour coded, with alerts above 90% and 95%.

let warnLevel = 90.0
let critLevel = 95.0
let notifyKey = "notificationsEnabled"

func memoryUsedPercent() -> Double? {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return nil }

    let pageSize = Double(vm_kernel_page_size)
    // Same breakdown Activity Monitor uses: app memory + wired + compressed
    let app = Double(stats.internal_page_count) - Double(stats.purgeable_count)
    let used = (app + Double(stats.wire_count) + Double(stats.compressor_page_count)) * pageSize
    return used / Double(ProcessInfo.processInfo.physicalMemory) * 100
}

func color(for pct: Double) -> NSColor {
    switch pct {
    case ..<80: return .systemGreen
    case ..<85: return .systemYellow
    case ..<90: return .systemOrange
    default: return .systemRed
    }
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation, UNUserNotificationCenterDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let usageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let notifyItem = NSMenuItem(title: "Notifications", action: #selector(toggleNotifications), keyEquivalent: "")
    let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
    let percentOnlyItem = NSMenuItem(title: "Show Percentage Only", action: #selector(togglePercentOnly), keyEquivalent: "")
    let percentageModeItem = NSMenuItem(title: "Percentage", action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
    let statusModeItem = NSMenuItem(title: "Status", action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
    let prefs = DisplayPreferences()
    var warned = false
    var alerted = false

    var notificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: notifyKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: notifyKey) }
    }

    var percentOnly: Bool {
        get { prefs.percentOnly }
        set { prefs.percentOnly = newValue }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        NSApp.activate(ignoringOtherApps: true)  // lets the permission prompt appear for a menu bar app
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let menu = NSMenu()
        menu.delegate = self
        usageItem.isEnabled = false
        menu.addItem(usageItem)
        menu.addItem(.separator())
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        percentageModeItem.representedObject = DisplayMode.percentage.rawValue
        statusModeItem.representedObject = DisplayMode.status.rawValue
        for i in [percentageModeItem, statusModeItem] { i.target = self; displayMenu.addItem(i) }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)
        for i in [percentOnlyItem, notifyItem, loginItem] { i.target = self; menu.addItem(i) }
        let test = NSMenuItem(title: "Send Test Notification", action: #selector(sendTest), keyEquivalent: "")
        test.target = self
        menu.addItem(test)
        menu.addItem(.separator())
        let credit = NSMenuItem(title: "Made by Simon Appleton / Pocket Giant", action: #selector(openSite), keyEquivalent: "")
        credit.target = self
        menu.addItem(credit)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        update()
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.update() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        percentageModeItem.state = prefs.mode == .percentage ? .on : .off
        statusModeItem.state = prefs.mode == .status ? .on : .off
        percentOnlyItem.state = percentOnly ? .on : .off
        notifyItem.state = notificationsEnabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc func openSite() {
        if let url = URL(string: "https://pocketgiant.games/") { NSWorkspace.shared.open(url) }
    }

    @objc func toggleNotifications() { notificationsEnabled.toggle() }

    @objc func togglePercentOnly() { percentOnly.toggle(); update() }

    @objc func selectDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = DisplayMode(rawValue: raw) else { return }
        prefs.mode = mode
        update()
    }

    // "Show Percentage Only" has no effect in Status mode, so grey it out there.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        item === percentOnlyItem ? prefs.mode == .percentage : true
    }

    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = "Move MemoryBar to your Applications folder and try again.\n\(error.localizedDescription)"
            alert.runModal()
        }
    }

    @objc func sendTest() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.notify("Memory test", "Notifications are working.", force: true)
                case .notDetermined:
                    NSApp.activate(ignoringOtherApps: true)
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        if granted { self.notify("Memory test", "Notifications are working.", force: true) }
                    }
                default:
                    self.showDeniedAlert()
                }
            }
        }
    }

    func showDeniedAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Notifications are turned off for MemoryBar"
        alert.informativeText = "Allow them in System Settings > Notifications > MemoryBar."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func notify(_ title: String, _ body: String, force: Bool = false) {
        guard force || notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // Show banners even though we're the "foreground" app
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])
    }

    func update() {
        guard let pct = memoryUsedPercent() else { return }
        item.button?.attributedTitle = NSAttributedString(
            string: menuBarTitle(pct: pct, mode: prefs.mode, percentOnly: percentOnly),
            attributes: [.foregroundColor: color(for: pct),
                         .font: NSFont.systemFont(ofSize: 12, weight: .medium)])
        usageItem.title = String(format: "Memory used: %.1f%%", pct)

        // Notify once per crossing; re-arm after dropping 2 points below the level.
        if pct > critLevel {
            if !alerted { notify("Memory critical", String(format: "%.0f%% of memory in use (over 95%%)", pct)) }
            alerted = true; warned = true
        } else if pct > warnLevel {
            if !warned { notify("Memory high", String(format: "%.0f%% of memory in use (over 90%%)", pct)) }
            warned = true
            if pct < critLevel - 2 { alerted = false }
        } else if pct < warnLevel - 2 {
            warned = false; alerted = false
        }
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
