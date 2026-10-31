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

MemoryBar is signed with Pocket Giant's Developer ID and notarised by Apple, so it opens normally; the first time, macOS asks you to confirm opening an app downloaded from the internet.

Made by [Pocket Giant](https://pocketgiant.games). Small studio. Big games.

## Build

Requires Xcode command line tools. `./build.sh` builds a universal `MemoryBar.app` and versioned DMG; `./build.sh install` also installs it into Applications.
