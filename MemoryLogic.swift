import Foundation

// Display logic kept free of AppKit so Tests/run-tests.swift can exercise it directly.

let displayModeKey = "displayMode"
let percentOnlyKey = "percentOnly"

enum DisplayMode: String {
    case percentage
    case status
}

/// Friendly label for a memory-used percentage. Uses the same rounding as the
/// "%.0f%%" menu bar text, so the label always agrees with the number shown elsewhere.
func statusLabel(for pct: Double) -> String {
    switch Int(min(max(pct, 0), 100).rounded()) {
    case ...30: return "Idle"
    case 31...50: return "Relaxed"
    case 51...70: return "Comfortable"
    case 71...80: return "Active"
    case 81...90: return "Busy"
    default: return "Stretched"
    }
}

/// Text shown in the menu bar for the given mode.
func menuBarTitle(pct: Double, mode: DisplayMode, percentOnly: Bool) -> String {
    switch mode {
    case .status: return statusLabel(for: pct)
    case .percentage: return String(format: percentOnly ? "%.0f%%" : "RAM %.0f%%", pct)
    }
}

/// Display preferences backed by UserDefaults (injectable for tests).
struct DisplayPreferences {
    var defaults: UserDefaults = .standard

    var mode: DisplayMode {
        get { defaults.string(forKey: displayModeKey).flatMap(DisplayMode.init(rawValue:)) ?? .percentage }
        nonmutating set { defaults.set(newValue.rawValue, forKey: displayModeKey) }
    }

    var percentOnly: Bool {
        get { defaults.bool(forKey: percentOnlyKey) }
        nonmutating set { defaults.set(newValue, forKey: percentOnlyKey) }
    }
}
