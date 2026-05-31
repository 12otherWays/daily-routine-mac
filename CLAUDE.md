# Daily Routine — Mac App

A native macOS daily task/routine tracker built with SwiftUI (Swift Package Manager, no Xcode project file).

## Build & Run

```bash
swift build                  # compile
swift run                    # run (or open the built binary directly)
.build/arm64-apple-macosx/debug/DailyRoutineApp
```

Requirements: macOS 14+, Swift 5.9+. Fonts **Instrument Serif** and **JetBrains Mono** must be installed system-wide (used via `Font.custom`).

## Project Structure

```
Sources/DailyRoutineApp/
├── DailyRoutineApp.swift          # @main entry, WindowGroup, keyboard shortcuts
├── ContentView.swift              # Root layout: header + content + nav bar + overlays
├── Models/
│   └── Models.swift               # RoutineTask, RoutineTemplate, AppData, Prefs, ViewMode, SettingsTab
├── Store/
│   └── AppStore.swift             # @MainActor ObservableObject; all state + persistence + navigation
├── Styles/
│   └── AppStyles.swift            # AppColors, AppFonts, EyebrowStyle, PillStyle, hardShadow modifier
├── Utils/
│   ├── DateUtils.swift            # Date key helpers, buildDayTabs, getWeekDays, getMonthDays, streak calc
│   └── StatsUtils.swift           # computeStreak, computeLongestStreak, completionByDay/Weekday/Category
└── Views/
    ├── Header/HeaderView.swift    # Title, eyebrow badge, stat items, ViewToggle, statsModeControl
    ├── NavBar/NavBarView.swift    # Prev/Next arrows, day tabs (day mode), period label (week/month), Today button, calendar popover
    ├── Sheet/
    │   ├── SheetView.swift        # Day-view table: column header + task rows + add footer
    │   └── TaskRowView.swift      # Single task row: checkbox, name (inline edit), priority menu, category menu, actions
    ├── Drawer/DrawerView.swift    # Slide-in detail panel: name, description, priority, category, done toggle
    ├── WeekView/WeekView.swift    # 7-column weekly grid
    ├── MonthView/MonthView.swift  # Monthly calendar grid
    ├── Stats/
    │   ├── StatsView.swift        # All-time statistics layout
    │   └── StatCard.swift         # Individual stat card component
    ├── Settings/
    │   ├── SettingsView.swift     # Slide-in settings panel (templates + categories tabs)
    │   ├── TemplatesEditor.swift  # CRUD for RoutineTemplate list
    │   └── CategoriesEditor.swift # CRUD for category string list
    ├── TemplatePicker/
    │   └── TemplatePickerView.swift # Sheet: pick a template to add to the active day
    └── Onboarding/
        └── OnboardingView.swift   # First-launch onboarding sheet
```

## Data Model

```swift
RoutineTask   { id, name, description, priority(high/med/low), category, done }
RoutineTemplate { id, name, description, priority, category }   // no `done`
AppData       { days: [String: [RoutineTask]], templates: [RoutineTemplate], categories: [String] }
Prefs         { onboarded: Bool }
```

- Day keys are `yyyy-MM-dd` strings (ISO, en_US_POSIX locale).
- Persisted to `UserDefaults` under keys `routine:v2` (AppData) and `routine:prefs` (Prefs).
- Saves are debounced 250ms via `DispatchWorkItem`.

## State Management

Everything lives in `AppStore` (single source of truth, injected as `@EnvironmentObject`):

| Property | Type | Purpose |
|---|---|---|
| `appData` | `AppData` | All tasks, templates, categories |
| `prefs` | `Prefs` | Onboarding flag |
| `activeDay` | `String` | Currently focused date key |
| `viewMode` | `ViewMode` | `.day / .week / .month / .stats` |
| `drawerTaskId` | `String?` | Non-nil → DrawerView slides in |
| `settingsTab` | `SettingsTab?` | Non-nil → SettingsView slides in |
| `templatePickerOpen` | `Bool` | Template picker sheet |
| `isLoading` | `Bool` | Initial load gate |

## View Modes

- **Day** — SheetView table for `activeDay`. NavBar shows 8 day tabs (4 past + today + 3 future).
- **Week** — WeekView 7-column grid. NavBar shows week range label.
- **Month** — MonthView calendar grid. NavBar shows month/year label.
- **Stats** — StatsView with all-time charts/cards. NavBar hidden.

## Sidebar Overlays

Both DrawerView and SettingsView are `.overlay(alignment: .trailing)` on `mainLayout`. They animate in/out via `.spring(response: 0.32, dampingFraction: 0.85)`.

A transparent backdrop (`Color.clear.contentShape(Rectangle())`) is applied to the **ScrollView only** (not the NavBar) so clicking the main content area closes sidebars without blocking nav buttons.

## Design System

**Neo-brutalist** aesthetic: flat colors, hard ink borders, no drop shadows (only hard offset shadows).

- Colors: defined in `AppColors` — `bg (#fafaf7)`, `surface (white)`, `ink (#0f172a)`, `inkMuted`, `inkFaint`, `accent (#0891b2)`, priority colors (high/med/low).
- Fonts: `Instrument Serif` for display/titles, `JetBrains Mono` for UI labels/data.
- `hardShadow(x:y:)` — paints an offset `AppColors.ink` rectangle behind a view (no blur).
- `eyebrow()` — mono 10pt, kerning 2, uppercase, inkMuted.
- `pill(color:)` — small mono label with colored background + border.

## ViewToggle (Day/Week/Month/Stats segmented control)

`struct ViewToggle` in `HeaderView.swift`. Uses a soft `borderWeak` container background with `cornerRadius: 7`. Active segment gets an ink fill. Hover state shows `borderMid`. Animates on mode change.

In Stats mode the header swaps to `statsModeControl` (`← DAY | STATS`) with the same visual style.

## Window

- `minWidth: 900, idealWidth: 1100, minHeight: 660, idealHeight: 820`
- `.windowStyle(.titleBar)` + `.windowToolbarStyle(.unified(showsTitle: false))`
- Keyboard shortcuts: `⌘←` prev, `⌘→` next, `⌘T` go to today

## Key Conventions

- `RoutineTask` is named with prefix to avoid conflict with `Swift.Task`.
- Date keys throughout are plain `String` — never pass `Date` across view boundaries.
- `buildDayTabs()` returns 8 keys: offsets `-4…+3` from today.
- Streak counts consecutive fully-completed days ending yesterday (today excluded by design).
- Column widths in SheetView: checkbox 44, priority 100, category 130, actions 72, name fills remainder.
- All padding inside `.frame()` calls, not after, to keep declared widths accurate.
