import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    // Tasks visible in the current view mode. Used only by the progress bar /
    // header counters — Stats has its own data path via `store.statsInput()`.
    private var visibleTasks: [RoutineTask] {
        switch store.viewMode {
        case .day:
            return store.tasks(for: store.activeDay)
        case .week:
            return store.tasks(forDays: getWeekDays(for: store.activeDay)).values.flatMap { $0 }
        case .month:
            return store.tasks(forDays: getMonthDays(for: store.activeDay)).values.flatMap { $0 }
        case .stats:
            return []
        }
    }

    private var done: Int  { visibleTasks.filter { $0.done }.count }
    private var total: Int { visibleTasks.count }
    private var pct: Int   { total == 0 ? 0 : Int(Double(done) / Double(total) * 100) }

    private var anyDrawerOpen: Bool {
        store.drawerTaskId != nil || store.settingsTab != nil || store.calendarDrawerOpen
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            AppColors.bg.ignoresSafeArea()

            if store.isLoading {
                loadingView
            } else {
                mainLayout
            }

            if anyDrawerOpen {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.drawerTaskId = nil
                        store.settingsTab = nil
                        store.calendarDrawerOpen = false
                    }
            }

            if store.drawerTaskId != nil {
                DrawerView()
                    .frame(width: 380)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if store.settingsTab != nil {
                SettingsView()
                    .frame(width: 420)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if store.calendarDrawerOpen {
                CalendarDrawerView()
                    .frame(width: 360)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        // The palette (AppColors) is hardcoded for a light aesthetic. Force light
        // appearance so native controls (TextField text, cursor, buttons) don't
        // adopt Dark Mode colors — otherwise typed text renders white-on-white.
        .preferredColorScheme(.light)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: store.drawerTaskId)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: store.settingsTab)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: store.calendarDrawerOpen)
        .sheet(isPresented: $store.templatePickerOpen) {
            TemplatePickerView()
                .environmentObject(store)
        }
        .sheet(isPresented: Binding(
            get: { !store.prefs.onboarded },
            set: { if !$0 { store.prefs.onboarded = true; store.savePrefs() } }
        )) {
            OnboardingView()
                .environmentObject(store)
        }
        // Surface persistence failures instead of dropping data silently.
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            ),
            presenting: store.lastError
        ) { _ in
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: { message in
            Text(message)
        }
    }

    private var mainLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeaderView(done: done, total: total, pct: pct)
                        .padding(.horizontal, 40)
                        .padding(.top, 32)
                        .padding(.bottom, 20)

                    if store.viewMode != .stats {
                        progressBar
                            .padding(.horizontal, 40)
                            .padding(.bottom, 28)
                    }

                    contentArea
                        .padding(.horizontal, 40)

                    footerText
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                }
            }

            if store.viewMode != .stats {
                NavBarView()
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.borderWeak)
                Rectangle()
                    .fill(AppColors.ink)
                    .frame(width: CGFloat(pct) / 100.0 * geo.size.width)
                    .animation(.easeInOut(duration: 0.4), value: pct)
            }
        }
        .frame(height: 2)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch store.viewMode {
        case .day:   SheetView()
        case .week:  WeekView()
        case .month: MonthView()
        case .stats: StatsView()
        }
    }

    private var footerText: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundColor(AppColors.inkFaint)
            Text(footerLabel)
                .font(AppFonts.mono(10))
                .kerning(1.2)
                .foregroundColor(AppColors.inkFaint)
                .textCase(.uppercase)
        }
    }

    private var footerLabel: String {
        switch store.viewMode {
        case .day:
            return store.activeDay == todayKey()
                ? "Single day · all editable · use nav bar to jump anywhere"
                : "Viewing \(formatKeyShort(store.activeDay))"
        case .week:  return "Weekly view · click any task to edit · + to add to a day"
        case .month: return "Monthly overview · click any day to open it"
        case .stats: return "All-time statistics · data updates as you complete tasks"
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
            Text("LOADING ROUTINE")
                .font(AppFonts.mono(12))
                .kerning(1)
                .foregroundColor(AppColors.inkMuted)
        }
    }
}
