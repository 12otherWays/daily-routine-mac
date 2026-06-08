# 📅 Daily Routine

A native macOS daily task & routine tracker built with SwiftUI — flat, neo-brutalist UI, no Xcode project file (pure Swift Package Manager).

Plan your day, reuse routines as templates, and watch your consistency build up in a GitHub-style contribution heatmap.

## ✨ Features

- 🗓️ **Day / Week / Month views** — track tasks per day, or zoom out to a weekly grid or monthly calendar.
- 📊 **Stats** — all-time statistics, current/longest streaks, a rolling 12-month contribution heatmap, and per-category breakdowns.
- 📋 **Templates** — save a set of tasks as a named routine and apply it to any day in one click.
- 🏷️ **Categories & priorities** — tag tasks (high/med/low) and group them by custom categories.
- 🔐 **Encrypted export / import** — back up and restore your data as a `.drbackup` file (obfuscated, see note below).
- 💾 **Local-first** — all data lives in a single JSON file under `~/Library/Application Support/DailyRoutine/`. No accounts, no network.

## 🧰 Requirements

- macOS 14+
- Swift 5.9+
- **Xcode Command Line Tools** (`xcode-select --install`) — full Xcode.app is **not** required to build or run the app.
- Running the **test suite** does need Xcode.app (XCTest ships inside Xcode, not the CLT).

## 🔨 Build & Run

```bash
swift build      # compile
swift run        # build and launch

# or run the built binary directly
.build/arm64-apple-macosx/debug/DailyRoutineApp
```

### 🧪 Tests

```bash
./scripts/test.sh   # auto-points DEVELOPER_DIR at Xcode for XCTest
```

## 📦 Distribution

```bash
./scripts/build-app.sh   # assembles build/Daily Routine.app
./scripts/build-dmg.sh   # builds the app, then packages build/Daily Routine.dmg
```

## 🗂️ Project Structure

```
Sources/DailyRoutineApp/
├── DailyRoutineApp.swift   # @main entry, window, keyboard shortcuts
├── ContentView.swift       # Root layout
├── Models/                 # RoutineTask, RoutineTemplate, AppData, Prefs
├── Store/                  # AppStore (state) + FileTaskRepository (persistence) + ExportCrypto
├── Styles/                 # Colors, fonts, layout constants
├── Utils/                  # Date helpers, stats math
└── Views/                  # Header, NavBar, day/week/month, Stats, Drawer, Settings, etc.

Tests/DailyRoutineAppTests/ # XCTest suite
scripts/                    # build-app.sh, build-dmg.sh, test.sh
packaging/                  # Info.plist, optional Fonts/ and AppIcon.icns
```

## 🔤 Fonts

The UI uses **Instrument Serif** (titles) and **JetBrains Mono** (labels/data) via `Font.custom`. When those fonts aren't installed, the app falls back to the system serif / monospaced designs, so it still looks right. To ship the fonts inside the `.app`, drop the `.ttf`/`.otf` files into `packaging/Fonts/` — they're bundled and auto-registered at launch.

## 🔏 A note on export "encryption"

Exported backups are AES-GCM encrypted so they aren't human-readable in a text editor — but the key is derived from a constant compiled into the app. This is deliberate **obfuscation, not real security**: anyone who inspects the binary (or this source) can recover the key. It's a conscious trade-off for a low-sensitivity to-do app, chosen to avoid the data-loss risk of a forgotten user passphrase. The app's own on-disk `routine.json` is stored as plain JSON so it stays repairable.

## 🤝 Contributing

Issues and pull requests are welcome. Please run `./scripts/test.sh` before submitting.
