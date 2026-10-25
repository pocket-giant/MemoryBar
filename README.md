# MemoryBar

A lightweight Mac menu bar app for keeping an eye on physical memory use.

- **RAM 42%** in the menu bar, green through yellow and orange to red as memory fills up.
- Uses the same measure as Activity Monitor: app memory, wired and compressed.
- Click the menu bar item for a compact dashboard with a five-minute trend, used and available RAM, and controls.
- Choose Percentage or Status in the menu bar, with an optional percentage-only label.
- Choose System, Light or Dark appearance.
- Opt in to notifications when memory passes 90% and again at 95%.
- No Dock icon, accounts or network connections.

## Download

Free for every Mac (macOS 13 or later, Apple Silicon and Intel). Get the latest `MemoryBar-*.dmg` from [Releases](../../releases/latest), open it and drag **MemoryBar** onto **Applications**.

MemoryBar is not yet notarised by Apple, so the first time you open it macOS will warn you. **Right-click MemoryBar in Applications → Open → Open.** You only need to do this once.

Made by [Pocket Giant](https://pocketgiant.games). Small studio. Big games.

## Build

Requires Xcode command line tools. `./build.sh` builds a universal `MemoryBar.app` and versioned DMG; `./build.sh install` also installs it into Applications.
