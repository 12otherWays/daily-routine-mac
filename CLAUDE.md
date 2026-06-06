# Daily Routine — Mac App

A native macOS daily task/routine tracker built with SwiftUI (Swift Package Manager, no Xcode project file).

## Build & Run

```bash
swift build                  # compile
swift run                    # run (or open the built binary directly)
.build/arm64-apple-macosx/debug/DailyRoutineApp

./scripts/test.sh            # run the test suite (auto-points DEVELOPER_DIR at Xcode for XCTest)
./scripts/build-app.sh       # assemble build/Daily Routine.app for distribution
```

Requirements: macOS 14+, Swift 5.9+, **Xcode Command Line Tools** (`xcode-select --install`). Full Xcode.app is NOT required **to build or run the app**. Fonts **Instrument Serif** and **JetBrains Mono** are used via `Font.custom`; when they aren't installed, `AppFonts` falls back to the system **serif/monospaced** designs so the UI still looks right (see Fonts below).

**Tests need Xcode.app**: XCTest ships inside Xcode, not the CLT. `scripts/test.sh` sets `DEVELOPER_DIR` to the installed Xcode for that one command without changing your global `xcode-select`. The app build itself stays CLT-only.

## Project Structure

```
Sources/DailyRoutineApp/
├── DailyRoutineApp.swift          # @main entry, WindowGroup, keyboard shortcuts
├── ContentView.swift              # Root layout: header + content + nav bar + overlays
├── Models/
│   ├── Models.swift               # RoutineTask, TemplateTask, RoutineTemplate, AppData, Prefs, ViewMode, SettingsTab
│   └── Entities.swift             # stub (SwiftData removed)
├── Store/
│   ├── AppStore.swift             # @MainActor ObservableObject; all state + navigation + cache + error surfacing
│   ├── TaskRepository.swift       # TaskRepository protocol + FileTaskRepository (atomic file store) + StorageError + v1→v2 migration
│   └── StoreMigration.swift       # stub (SwiftData migration removed)
├── Styles/
│   └── AppStyles.swift            # AppColors, AppFonts, EyebrowStyle, PillStyle, hardShadow modifier
├── Utils/
│   ├── DateUtils.swift            # Date key helpers, buildDayTabs, getWeekDays, getMonthDays, streak calc
│   └── StatsUtils.swift           # computeStreak, computeLongestStreak, completionByDay/Weekday/Category
└── Views/
    ├── Header/HeaderView.swift    # Title, eyebrow badge, stat items, ViewToggle, statsModeControl
    ├── NavBar/NavBarView.swift    # Prev/Next arrows, day tabs (day mode), period label (week/month), Today button, calendar popover
    ├── Calendar/CalendarDrawerView.swift  # Slide-in calendar drawer
    ├── Sheet/
    │   ├── SheetView.swift        # Day-view table: column header + task rows + add footer
    │   └── TaskRowView.swift      # Single task row: checkbox, name (inline edit), priority pill, category menu, actions
    ├── Drawer/DrawerView.swift    # Slide-in detail panel: name, description, priority, category, done toggle
    ├── WeekView/WeekView.swift    # 7-column weekly grid
    ├── MonthView/MonthView.swift  # Monthly calendar grid
    ├── Stats/
    │   ├── StatsView.swift        # All-time statistics layout
    │   └── StatCard.swift         # Individual stat card component
    ├── Settings/
    │   ├── SettingsView.swift     # Slide-in settings panel (templates + categories tabs)
    │   ├── TemplatesEditor.swift  # CRUD for RoutineTemplate groups; accordion rows with inline add-task form
    │   └── CategoriesEditor.swift # CRUD for category string list
    ├── TemplatePicker/
    │   └── TemplatePickerView.swift # Sheet: pick a template (adds all its tasks); save today's tasks as template
    └── Onboarding/
        └── OnboardingView.swift   # First-launch onboarding sheet

Tests/DailyRoutineAppTests/       # XCTest suite (date utils, stats math, file repo round-trip, migration, export/import)
scripts/
├── build-app.sh                   # assemble + (optionally) codesign Daily Routine.app
└── test.sh                        # run tests with Xcode's XCTest SDK
packaging/
├── Info.plist                     # bundle metadata; ATSApplicationFontsPath=Fonts auto-registers bundled fonts
├── Fonts/                         # (optional) drop .ttf/.otf here to ship fonts with the app
└── AppIcon.icns                   # (optional) app icon
```

## Data Model

```swift
RoutineTask     { id, name, description, priority(high/med/low), category, done }
TemplateTask    { id, name, description, priority, category }   // task inside a template group; has toTask()
RoutineTemplate { id, name, tasks: [TemplateTask] }             // named group of tasks
AppData         { days: [String: [RoutineTask]], templates: [RoutineTemplate], categories: [String] }
Prefs           { onboarded: Bool }
```

- Day keys are `yyyy-MM-dd` strings (ISO, en_US_POSIX locale).
- `AppData` is persisted as a single JSON document at `~/Library/Application Support/DailyRoutine/routine.json`, written **atomically** with a rolling `routine.backup.json` copy.
- `Prefs` is persisted to `UserDefaults` under key `routine:prefs` (small, preference-shaped — UserDefaults is fine here).
- All saves are debounced 250ms via `DispatchWorkItem` (text edits) or immediate (structural mutations). `AppDelegate.applicationWillTerminate` calls `store.flushPendingSave()` so an edit typed within the debounce window before ⌘Q is never lost.
- **v1 → v2 migration**: old flat `RoutineTemplate { id, name, description, priority, category }` records are auto-migrated on first load — each becomes a `RoutineTemplate` group containing one `TemplateTask`. Migrated data is immediately re-persisted.

## Persistence Layer

All data access goes through the `TaskRepository` protocol (`TaskRepository.swift`). The concrete implementation is `FileTaskRepository`, which:

- **Storage**: writes the whole `AppData` to a JSON file in Application Support using `.atomic` writes. Before each overwrite it rolls the current good file to `routine.backup.json`, so a corrupt/failed write still leaves one recoverable copy. (UserDefaults was rejected for primary data — it's for preferences, has no atomic guarantee, and `cfprefsd` can drop large blobs.)
- **Load order on init**: primary file → backup file → legacy `routine:v2` UserDefaults blob (migrates pre-file installs) → `AppData.defaultSeed`. Any non-primary source is immediately re-persisted to the primary file. Takes an injectable `directory:` for tests.
- **Errors**: `save()`/`exportData()`/`importData()` throw `StorageError` (a `LocalizedError`). `AppStore` runs every write through `perform { … }`, which catches and publishes a user-facing message to `lastError`; `ContentView` shows it in an `.alert`. **No `try?` swallowing on the save path** — failures are never silent.
- **Export/import**: `exportData()` returns an **encrypted** backup; `importData(_:)` decrypts then replaces the dataset and re-saves. Wired to File ▸ "Export Data…" (⇧⌘E) / "Import Data…" (⇧⌘I) in `DailyRoutineApp.swift` via `NSSavePanel`/`NSOpenPanel` (saved as `.drbackup`; import also accepts plain `.json`). Import asks for confirmation first, then `AppStore.importSnapshot` clears all caches and refreshes.
- **Export encryption** (`ExportCrypto.swift`): exports are AES-GCM encrypted via CryptoKit so the file isn't human-readable. The container is `magic("DRBK01") + sealed.combined`. The key is derived (SHA-256) from a **constant compiled into the app** — this is deliberate **obfuscation, not real security** (anyone inspecting the binary can recover the key), chosen to avoid the data-loss risk of a user passphrase. `importData` auto-detects: magic header → decrypt; otherwise decode as plain JSON (back-compat with pre-encryption exports). The app's own on-disk `routine.json` stays **plain** (unencrypted) so it remains repairable.

`AppStore` holds a `private let repository: TaskRepository` and a per-day task cache (`dayCache`). After any mutation, `invalidate(day:)` clears the relevant cache entry and increments `dataVersion` (a `@Published` counter) to trigger SwiftUI re-renders.

## Fonts

`AppFonts` detects whether `Instrument Serif` / `JetBrains Mono` are available (`NSFont(name:size:)`) once, and uses `Font.custom` when present, otherwise `.system(size:design:.serif)` / `.system(size:design:.monospaced)`. This keeps the look intact on machines without the fonts (where plain `Font.custom` would silently fall back to the default *sans-serif*). To ship the fonts with the app, drop the `.ttf`/`.otf` files in `packaging/Fonts/` — `build-app.sh` copies them into the bundle and `ATSApplicationFontsPath` auto-registers them at launch.

## Distribution

`scripts/build-app.sh` builds the release binary and assembles `build/Daily Routine.app` (Info.plist, bundled fonts, optional icon). Set `SIGN_ID="Developer ID Application: …"` to code-sign; notarize separately with `xcrun notarytool` + `stapler` (commands in the script header).

## State Management

Everything lives in `AppStore` (single source of truth, injected as `@EnvironmentObject`):

| Property | Type | Purpose |
|---|---|---|
| `appData` | via `repository` | All tasks, templates, categories |
| `prefs` | `Prefs` | Onboarding flag |
| `activeDay` | `String` | Currently focused date key |
| `viewMode` | `ViewMode` | `.day / .week / .month / .stats` |
| `drawerTaskId` | `String?` | Non-nil → DrawerView slides in |
| `settingsTab` | `SettingsTab?` | Non-nil → SettingsView slides in |
| `calendarDrawerOpen` | `Bool` | Calendar drawer slide-in |
| `templatePickerOpen` | `Bool` | Template picker sheet |
| `isLoading` | `Bool` | Initial load gate |

## View Modes

- **Day** — SheetView table for `activeDay`. NavBar shows 8 day tabs (4 past + today + 3 future).
- **Week** — WeekView 7-column grid. NavBar shows week range label.
- **Month** — MonthView calendar grid. NavBar shows month/year label.
- **Stats** — StatsView with all-time charts/cards. NavBar hidden.

## Stats — Contribution Heatmap

`ContributionHeatmap` (private struct in `StatsView.swift`) renders a rolling ~12-month GitHub-style grid (`weekCount = 52`).

- **Layout**: a `VStack` of a top control bar + the grid below. The grid spans the full card width (`maxWidth: .infinity`); its width is measured via `HeatWidthKey` preference and drives the square `cell` size so the weekday-label gutter (`labelW = 34`) + columns exactly fill the row.
- **Top control bar** (`topBar`, single `HStack`): legend swatches on the left (No tasks / Tasks added / All done), then a `Spacer`, then the category filter menu, the state filter menu, the `rangeLabel` (e.g. "Jan 25 – Jan 26"), and the prev/next `<` `>` nav buttons — all on one line.
- **Cell gap**: `gap = 6` between cells (also subtracted from the available width in the `cell` calc).
- **Navigation**: prev/next shift the window ±12 months; next is disabled at present (`atPresent`).
- **Filters**: `category` (nil = all) and `stateFilter` (`HeatStateFilter`) feed `heatmapWeeks(...)`. Today's cell is outlined with `AppColors.accent`.

### By Category (`CategoryBreakdown`)

Per-category progress rows (top 8 by volume). Each row: category label (100w), a horizontal track + ink fill bar, and a `done/total` count. Track and fill are `clipShape(RoundedRectangle(cornerRadius: 4))` for a soft curve (not square).

## NavBar — Button Behaviour

`NavBarView` (`Views/.../NavBarView.swift`) prev/next arrows are `Button` + `.buttonStyle(.plain)` with an SF Symbol label. The image carries `.contentShape(Rectangle())` so the full 36×44 frame is the hit target — without it only the chevron glyph is clickable and the arrows feel dead. (Same fix pattern as the TaskRowView checkbox.)

## Sidebar Overlays

DrawerView, SettingsView, and CalendarDrawerView are rendered in a `ZStack(alignment: .trailing)` in `ContentView`. They animate in/out via `.spring(response: 0.32, dampingFraction: 0.85)`.

When any drawer is open (`anyDrawerOpen`), a `Color.black.opacity(0.12)` overlay covers the main layout; tapping it dismisses all drawers. This overlay does NOT cover the NavBar.

## TaskRowView — Row Behaviour

Column widths: checkbox 44, priority 100, category 130, actions 72, name fills remainder.

- **Checkbox**: `.buttonStyle(.plain)` + `.contentShape(Rectangle())` ensures the full 44pt column is tappable, not just the 20×20 graphic.
- **Priority badge**: Rounded rect (cornerRadius 4), background/border applied to the `Menu` view itself (not inside the label) to avoid macOS borderless-button label stripping. Height forced via `.frame(height: 20)`. `.menuIndicator(.hidden)` suppresses the macOS dropdown chevron on both priority and category menus.
- **Action icons** (description + delete): Always visible at `AppColors.inkMuted`; per-button `onHover` state darkens each independently. Description goes `AppColors.ink` on hover or when drawer is open. Delete goes `AppColors.high` (red) on hover.
- **Delete confirmation**: Clicking trash sets `showDeleteConfirm = true`; an `.alert` asks for confirmation before `store.deleteTask` is called.

## Design System

**Neo-brutalist** aesthetic: flat colors, hard ink borders, no drop shadows (only hard offset shadows).

- Colors: defined in `AppColors` — `bg (#fafaf7)`, `surface (white)`, `ink (#0f172a)`, `inkMuted`, `inkFaint`, `accent (#0891b2)`, priority colors (high/med/low).
- Fonts: `Instrument Serif` for display/titles, `JetBrains Mono` for UI labels/data.
- `hardShadow(x:y:)` — paints an offset `AppColors.ink` rectangle behind a view (no blur).
- `eyebrow()` — mono 10pt, kerning 2, uppercase, inkMuted.
- `pill(color:)` — small mono label with colored background + border (used in non-Menu contexts).

## ViewToggle (Day/Week/Month/Stats segmented control)

`struct ViewToggle` in `HeaderView.swift`. Uses a soft `borderWeak` container background with `cornerRadius: 7`. Active segment gets an ink fill. Hover state shows `borderMid`. Animates on mode change.

In Stats mode the header swaps to `statsModeControl` (`← DAY | STATS`) with the same visual style.

## Window

- `minWidth: 900, idealWidth: 1100, minHeight: 660, idealHeight: 820`
- `.windowStyle(.titleBar)` + `.windowToolbarStyle(.unified(showsTitle: false))`
- Keyboard shortcuts: `⌘←` prev, `⌘→` next, `⌘T` go to today

## Template System

Templates are named groups of tasks. Applying a template inserts all of its tasks into the active day at once.

- **`TemplatesEditor`** (Settings → Templates tab): create a group by name, then expand it to add tasks inline (name + priority + category). Delete individual tasks with ✕ or the whole group with trash.
- **`TemplatePickerView`**: card grid — each card shows template name, task-count badge, and a bullet preview of up to 3 tasks. Clicking a card calls `store.addTasksFromTemplate(_:to:)` and dismisses. Footer shows a "Save today's N tasks as template" button that reveals an inline name field calling `store.saveCurrentDayAsTemplate(name:)`.
- **`AppStore` methods**: `addTasksFromTemplate(_:to:)` loops over `template.tasks` and inserts each; `saveCurrentDayAsTemplate(name:)` snapshots the active day's tasks into a new `RoutineTemplate`.

## Key Conventions

- `RoutineTask` is named with prefix to avoid conflict with `Swift.Task`.
- Date keys throughout are plain `String` — never pass `Date` across view boundaries.
- `buildDayTabs()` returns 8 keys: offsets `-4…+3` from today.
- Streak counts consecutive fully-completed days ending yesterday (today excluded by design).
- All padding inside `.frame()` calls, not after, to keep declared widths accurate.
- SwiftData is **not used** — the `@Model` macro requires full Xcode.app and is incompatible with Command Line Tools only builds.
