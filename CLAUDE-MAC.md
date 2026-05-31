# CLAUDE-MAC.md

> Context file for the **Daily Routine macOS app** (SwiftUI). Read alongside the web app's CLAUDE.md — they share the same data model and design language but no code.

---

## 1. What this is

SwiftUI Mac app mirroring the web app's Daily Routine tracker. Same data schema (compatible JSON), same editorial design language, same feature set. Built for macOS 14+ (Sonoma and later). This is Phase 2 of the platform roadmap.

---

## 2. Stack & tech

- **Swift 6 / SwiftUI** — no UIKit, no AppKit (except window config).
- **State**: `AppStore` — an `@MainActor` `ObservableObject` class. Injected via `environmentObject`. All global state and actions live there. Views subscribe with `@EnvironmentObject var store: AppStore`.
- **Persistence**: `UserDefaults` with the same JSON schema as the web app (`routine:v2` for tasks, `routine:prefs` for preferences). `JSONEncoder/JSONDecoder` for serialization. Save is debounced 250ms via `DispatchWorkItem`.
- **Charts**: `Charts` framework (Swift Charts, built-in since Xcode 14 / macOS 13). No third-party chart library.
- **Icons**: SF Symbols only (no lucide-react equivalent; map web icons to their SF Symbols counterparts).
- **No third-party dependencies** — pure Swift Package with a single executable target.

---

## 3. File layout

```
daily-routine-mac/
├── Package.swift                          ← SPM config, macOS 14+
├── Sources/
│   └── DailyRoutineApp/
│       ├── DailyRoutineApp.swift          ← @main App, window config, keyboard shortcuts
│       ├── ContentView.swift              ← main layout shell (header + content + navBar + overlays)
│       ├── Models/
│       │   └── Models.swift               ← RoutineTask, RoutineTemplate, AppData, Priority, ViewMode, SettingsTab, Prefs
│       ├── Store/
│       │   └── AppStore.swift             ← @MainActor ObservableObject with all state + actions
│       ├── Styles/
│       │   └── AppStyles.swift            ← AppColors, AppFonts, Color(hex:), .eyebrow(), .pill(), .hardShadow()
│       ├── Utils/
│       │   ├── DateUtils.swift            ← todayKey, dateKey, buildDayTabs, getWeekDays, getMonthDays, formatKeyShort
│       │   └── StatsUtils.swift           ← computeStreak, computeLongestStreak, computePerfectDays, completionByDay, etc.
│       └── Views/
│           ├── Header/
│           │   └── HeaderView.swift       ← title, stats, segmented ViewToggle, stats-mode two-button control, gear
│           ├── Sheet/
│           │   ├── SheetView.swift        ← spreadsheet layout (column header + task rows + add footer)
│           │   └── TaskRowView.swift      ← single task row (checkbox, name, priority menu, category menu, actions)
│           ├── NavBar/
│           │   └── NavBarView.swift       ← bottom navigation (day tabs or period label + prev/next/today)
│           ├── WeekView/
│           │   └── WeekView.swift         ← 7-column week grid
│           ├── MonthView/
│           │   └── MonthView.swift        ← calendar month grid
│           ├── Stats/
│           │   ├── StatsView.swift        ← KPI cards + Swift Charts + activity heatmap + category breakdown
│           │   └── StatCard.swift         ← single KPI card with `primary` variant for gamification
│           ├── Drawer/
│           │   └── DrawerView.swift       ← right-side task detail overlay (name, description, priority, category)
│           ├── Settings/
│           │   ├── SettingsView.swift     ← right-side settings overlay with tab switcher
│           │   ├── TemplatesEditor.swift  ← add/delete templates
│           │   └── CategoriesEditor.swift ← add/delete categories
│           ├── TemplatePicker/
│           │   └── TemplatePickerView.swift ← modal sheet, card grid
│           └── Onboarding/
│               └── OnboardingView.swift   ← first-launch modal with how-it-works points
└── CLAUDE-MAC.md
```

---

## 4. Data model

**Exact same schema as the web app** (§3 of the main CLAUDE.md). Stored as JSON in `UserDefaults`.

Swift types map to web app JSON:
- `RoutineTask` → web app's `Task` type (same JSON keys: `id`, `name`, `description`, `priority`, `category`, `done`)
- `RoutineTemplate` → web app's `Template` type (same keys minus `done`)
- `AppData.days: [String: [RoutineTask]]` → `days` dict keyed by `YYYY-MM-DD`

The type is named `RoutineTask` (not `Task`) in Swift to avoid conflict with `Swift.Task` from structured concurrency.

**To add a new task field**: extend `RoutineTask` in `Models.swift`, add it to `TaskRowView` and `DrawerView`, add to `TemplatesEditor` + `TemplatePickerView`. Bump storage key to `routine:v3` and write a migration in `AppStore.load()`.

---

## 5. Design language

Mirrors the web app exactly — see §5 of the main CLAUDE.md.

**Colors**: Defined in `AppStyles.swift` as `AppColors.*` enum. Use `AppColors.ink`, `AppColors.inkMuted`, etc. — never hardcode hex in views.

**Fonts**: `AppFonts.display/displayItalic/mono/monoMedium/monoBold(size)` helpers. Requires `Instrument Serif` and `JetBrains Mono` to be installed on the system or bundled in the Xcode target.

**To bundle fonts in Xcode**: Add font files to the target, add them to `Info.plist` under `UIAppFonts` / `ATSApplicationFontsPath`. In SPM, add them as `resources:` in `Package.swift`.

**Hard offset shadow** (neo-brutalist, no blur): use `.hardShadow()` modifier from `AppStyles.swift`. Equivalent to `shadow(color: AppColors.ink, radius: 0, x: 4, y: 4)`.

**SF Symbols → Lucide icon mapping**:

| Web (lucide-react) | Mac (SF Symbols) |
|---|---|
| `Flame` | `flame.fill` |
| `Settings` | `gearshape` |
| `ChevronLeft/Right` | `chevron.left/right` |
| `BarChart2` | `chart.bar` / `chart.bar.fill` |
| `FileText` | `doc.text` |
| `Trash2` | `trash` |
| `Check` | `checkmark` |
| `Plus` | `plus` |
| `Calendar` | `calendar` |

---

## 6. State management

All state in `AppStore` (`@MainActor ObservableObject`). Views never hold business logic state — only local UI state (`@State` for hover, editing, etc.).

**Key state slices**:
- `appData: AppData` — the full persisted data (days, templates, categories)
- `prefs: Prefs` — preferences (onboarded flag; extend for future prefs)
- `activeDay: String` — currently selected `YYYY-MM-DD`
- `viewMode: ViewMode` — `.day`, `.week`, `.month`, `.stats`
- `drawerTaskId: String?` — which task has the detail drawer open (nil = closed)
- `settingsTab: SettingsTab?` — which settings tab is active (nil = closed)
- `templatePickerOpen: Bool` — controls the template picker sheet

**Save debounce**: `scheduleSave()` captures `appData` by value at call time, cancels the previous `DispatchWorkItem`, and schedules a new one 250ms out. This matches the web app's behavior.

---

## 7. Window & navigation

- Minimum window size: 900×650. The layout is not responsive below this.
- Keyboard shortcuts registered in `DailyRoutineApp.swift` commands:
  - `Cmd+Left` → `goPrev()`
  - `Cmd+Right` → `goNext()`
  - `Cmd+T` → jump to today
- The NavBar at the bottom mirrors the web app's 8-day tab strip (4 past + today + 3 upcoming).
- The drawer and settings panel slide in from the right as overlays (not separate windows).

---

## 8. Stats screen

Same design intent as the web app (§12 of main CLAUDE.md). Uses Swift Charts for:
- **30-day bar chart** — `BarMark` with date on x-axis, completion % on y-axis
- **Weekday chart** — horizontal `BarMark` with day name on y-axis, avg completion % on x-axis
- **Activity heatmap** — custom `HStack` of `VStack` columns (12 weeks × 7 days), not a chart
- **Category breakdown** — custom `GeometryReader`-based bars

`StatCard` has a `primary: Bool` prop for gamification milestones (inverted colors: white text on black).

---

## 9. Building & running

Xcode is required to build and run the app as a proper `.app` bundle.

**To open in Xcode**: double-click `Package.swift` — Xcode opens it as an SPM project.

**To build via CLI** (produces binary only, not a `.app`):
```bash
cd daily-routine-mac
swift build -c release
```

**Font setup for Xcode**: In the Xcode project, add the font files as resources and list them in `Info.plist`:
```xml
<key>ATSApplicationFontsPath</key>
<string>Fonts</string>
```

---

## 10. Things to NOT do

- **Don't use `Task` as a model type name** — conflicts with `Swift.Task`. Use `RoutineTask`.
- **Don't use UIKit** — this is a pure SwiftUI Mac app.
- **Don't add gamification without the user's spec** — `StatCard` primary variant is ready; wait for the design.
- **Don't add notifications, reminders, or sounds** without asking.
- **Don't make past days read-only** without asking.
- **Don't auto-copy tasks between days** — templates are the explicit mechanism.
- **Don't introduce SPM dependencies** without discussing — the app intentionally has none.

---

## 11. Data sharing with the web app

The JSON schema is identical. Future sync options:
- **iCloud**: Store the JSON blob in `NSUbiquitousKeyValueStore` instead of `UserDefaults`. Minimal code change in `AppStore.load()` / `scheduleSave()`.
- **Export/import**: Serialize `appData` to JSON and save to a file; the web app can import it.
- **Local network**: Both apps could talk to a small local HTTP server — but this is beyond the current scope.

---

*Last updated: 2026-05-25.*
