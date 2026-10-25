import Foundation

// Minimal test runner (no XCTest needed): ./test.sh

var failures = 0
var checks = 0

func expect<T: Equatable>(_ actual: T, _ expected: T, _ name: String, line: Int = #line) {
    checks += 1
    if actual != expected {
        failures += 1
        print("FAIL line \(line): \(name): got \(actual), expected \(expected)")
    }
}

func freshDefaults() -> UserDefaults {
    let suite = "MemoryBarTests-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}

// MARK: Percentage boundaries

let boundaries: [(Double, String)] = [
    (0, "Idle"), (15, "Idle"), (30, "Idle"), (30.4, "Idle"),
    (31, "Relaxed"), (30.5, "Relaxed"), (50, "Relaxed"), (50.4, "Relaxed"),
    (51, "Comfortable"), (70, "Comfortable"), (70.4, "Comfortable"),
    (71, "Active"), (80, "Active"), (80.4, "Active"),
    (81, "Busy"), (90, "Busy"), (90.4, "Busy"),
    (91, "Stretched"), (90.5, "Stretched"), (100, "Stretched"),
    (-1, "Idle"), (104, "Stretched"),
]
for (pct, label) in boundaries { expect(statusLabel(for: pct), label, "statusLabel(\(pct))") }

// Every whole percentage 0...100 maps to exactly the table in the spec.
for p in 0...100 {
    let want: String
    switch p {
    case 0...30: want = "Idle"
    case 31...50: want = "Relaxed"
    case 51...70: want = "Comfortable"
    case 71...80: want = "Active"
    case 81...90: want = "Busy"
    default: want = "Stretched"
    }
    expect(statusLabel(for: Double(p)), want, "statusLabel(\(p))")
}

// MARK: Menu bar title / mode switching

expect(menuBarTitle(pct: 42.3, mode: .percentage, percentOnly: false), "RAM 42%", "percentage title")
expect(menuBarTitle(pct: 42.3, mode: .percentage, percentOnly: true), "42%", "percentage-only title")
expect(menuBarTitle(pct: 42.3, mode: .status, percentOnly: false), "Relaxed", "status title")
expect(menuBarTitle(pct: 42.3, mode: .status, percentOnly: true), "Relaxed", "status ignores percentOnly")
// Same reading, switched live, then labels follow changing usage.
let live = DisplayPreferences(defaults: freshDefaults())
expect(menuBarTitle(pct: 85, mode: live.mode, percentOnly: live.percentOnly), "RAM 85%", "default shows percentage")
live.mode = .status
expect(menuBarTitle(pct: 85, mode: live.mode, percentOnly: live.percentOnly), "Busy", "switched to status")
expect(menuBarTitle(pct: 95, mode: live.mode, percentOnly: live.percentOnly), "Stretched", "label updates with usage")
live.mode = .percentage
expect(menuBarTitle(pct: 95, mode: live.mode, percentOnly: live.percentOnly), "RAM 95%", "switched back")

// MARK: Preference persistence

let store = freshDefaults()
expect(DisplayPreferences(defaults: store).mode, .percentage, "default mode is percentage")
expect(DisplayPreferences(defaults: store).percentOnly, false, "percentOnly defaults off")
DisplayPreferences(defaults: store).mode = .status
expect(DisplayPreferences(defaults: store).mode, .status, "status persists to a new instance")
DisplayPreferences(defaults: store).percentOnly = true
expect(DisplayPreferences(defaults: store).percentOnly, true, "percentOnly persists")
expect(DisplayPreferences(defaults: store).mode, .status, "setting percentOnly leaves mode alone")
expect(DisplayPreferences(defaults: store).appearance, .system, "default appearance follows system")
DisplayPreferences(defaults: store).appearance = .dark
expect(DisplayPreferences(defaults: store).appearance, .dark, "appearance persists")
store.set("garbage", forKey: displayModeKey)
expect(DisplayPreferences(defaults: store).mode, .percentage, "invalid stored value falls back to percentage")
store.set("garbage", forKey: appearanceKey)
expect(DisplayPreferences(defaults: store).appearance, .system, "invalid appearance falls back to system")

print(failures == 0 ? "All \(checks) checks passed" : "\(failures) of \(checks) checks FAILED")
exit(failures == 0 ? 0 : 1)
