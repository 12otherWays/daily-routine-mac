# Daily Routine — Mac App

A native macOS daily task/routine tracker built with SwiftUI (Swift Package Manager, no Xcode project file).

## Build & Run

```bash
swift build                  # compile
swift run                    # run (or open the built binary directly)
.build/arm64-apple-macosx/debug/DailyRoutineApp
```

Requirements: macOS 14+, Swift 5.9+, **Xcode Command Line Tools** (`xcode-select --install`). Full Xcode.app is NOT required. Fonts **Instrument Serif** and **JetBrains Mono** must be installed system-wide (used via `Font.custom`).

## Project Structure

```
Sources/DailyRoutineApp/
├── DailyRoutineApp.swift          # @main entry, WindowGroup, keyboard shortcuts
├── ContentView.swift              # Root layout: header + content + nav bar + overlays
├── Models/
│   ├── Models.swift               # RoutineTask, TemplateTask, RoutineTemplate, AppData, Prefs, ViewMode, SettingsTab
│   └── Entities.swift             # stub (SwiftData removed)
├── Store/
│   ├── AppStore.swift             # @MainActor ObservableObject; all state + navigation + cache
│   ├── TaskRepository.swift       # TaskRepository protocol + UserDefaultsTaskRepository + v1→v2 migration
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
- `AppData` is persisted as a single JSON blob to `UserDefaults` under key `routine:v2`.
- `Prefs` is persisted to `UserDefaults` under key `routine:prefs`.
- All saves are debounced 250ms via `DispatchWorkItem` (text edits) or immediate (structural mutations).
- **v1 → v2 migration**: old flat `RoutineTemplate { id, name, description, priority, category }` records are auto-migrated on first load by `UserDefaultsTaskRepository.init()` — each becomes a `RoutineTemplate` group containing one `TemplateTask`. Migrated data is immediately resaved.

## Persistence Layer

All data access goes through the `TaskRepository` protocol (`TaskRepository.swift`). The concrete implementation is `UserDefaultsTaskRepository`, which:

- Loads `AppData` from `UserDefaults` on init; tries new format first, falls back to v1 migration, then seeds `AppData.defaultSeed` on fresh install.
- Operates on the full dataset in memory.
- Flushes to `UserDefaults` on every `save()` call.

`AppStore` holds a `private let repository: TaskRepository` and a per-day task cache (`dayCache`). After any mutation, `invalidate(day:)` clears the relevant cache entry and increments `dataVersion` (a `@Published` counter) to trigger SwiftUI re-renders.

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
