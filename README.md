# MemoryBar

A tiny Mac menu bar app that shows how much memory you are using, as one colour-coded number. Nothing else on screen.

- **RAM 42%** in the menu bar, green through yellow and orange to red as memory fills up.
- Uses the same measure as Activity Monitor: app memory, wired and compressed.
- Optional notification when memory passes 90% and again at 95%.
- No window, no Dock icon, no accounts, no network connections.

## Download

Free for every Mac (macOS 13 or later, Apple Silicon and Intel). Get the latest `MemoryBar-*.dmg` from [Releases](../../releases/latest), open it and drag **MemoryBar** onto **Applications**.

MemoryBar is not yet notarised by Apple, so the first time you open it macOS will warn you. **Right-click MemoryBar in Applications → Open → Open.** You only need to do this once.

Made by Simon Appleton / [Pocket Giant](https://pocketgiant.games/).

## Build

Requires Xcode command line tools. `./build.sh` builds a universal `MemoryBar.app` and `MemoryBar-1.0.dmg`; `./build.sh install` also installs it into Applications.
