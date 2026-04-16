import SwiftUI
import SwiftData
import WidgetKit

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]

    @AppStorage("gradientTheme")     private var themeRawValue:      String = GradientTheme.fire.rawValue
    @AppStorage("calorieGoal")       private var calorieGoal:        Double = 2000
    @AppStorage("newHeroStyle")      private var newHeroStyle:       Bool   = false
    @AppStorage("themeAppearance")   private var appearanceRawValue: String = ThemeAppearance.auto.rawValue
    @AppStorage("heroHintDismissed") private var heroHintDismissed:  Bool   = false
    @Environment(\.colorScheme) private var systemScheme

    private var theme:      GradientTheme   { GradientTheme(rawValue: themeRawValue) ?? .fire }
    private var appearance: ThemeAppearance { ThemeAppearance(rawValue: appearanceRawValue) ?? .auto }
    private var scheme:     ColorScheme     { appearance.colorScheme ?? systemScheme }

    @State private var showLog          = false
    @State private var startLogInScan   = false
    @State private var logIsPressing    = false
    @State private var showSettings     = false

    let proteinGoal: Double = 150
    let carbsGoal:   Double = 250
    let fatGoal:     Double = 65

    private var today: [FoodEntry] {
        let start = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.timestamp >= start }
    }

    private var totalCal:     Double { today.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { today.reduce(0) { $0 + $1.protein  } }
    private var totalCarbs:   Double { today.reduce(0) { $0 + $1.carbs    } }
    private var totalFat:     Double { today.reduce(0) { $0 + $1.fat      } }

    private var balance:   Double { totalCal - calorieGoal }
    private var remaining: Double { calorieGoal - totalCal }
    private var ratio:     Double { calorieGoal > 0 ? totalCal / calorieGoal : 0 }
    private var grad:      (Color, Color) { gradientColors(for: ratio, theme: theme) }

    // Three zones: surplus / on track (±150) / deficit
    private var energyZone: EnergyZone {
        if balance > 150  { return .surplus }
        if balance < -150 { return .deficit }
        return .onTrack
    }

    // ── Old hero ─────────────────────────────────────────────
    private var heroNumber: String { abs(Int(balance)).formatted() }

    // ── New hero (dev toggle) ─────────────────────────────────
    private var heroNumberNew: String {
        switch energyZone {
        case .surplus: return "+\(abs(Int(balance)).formatted())"
        case .deficit: return abs(Int(remaining)).formatted()
        case .onTrack: return abs(Int(balance)) < 5
                            ? "✓"
                            : abs(Int(balance)).formatted()
        }
    }
    private var heroColorNew: Color {
        switch energyZone {
        case .surplus: return Color(hex: "FFB060")    // warm amber
        case .deficit: return .white
        case .onTrack: return Color(hex: "9EF0B8")    // soft green
        }
    }
    private var heroSubtitleNew: String {
        switch energyZone {
        case .surplus: return "kcal over goal"
        case .deficit: return "kcal remaining"
        case .onTrack: return abs(Int(balance)) < 5 ? "bang on target" : "on target"
        }
    }

    var body: some View {
        ZStack {
            AnimatedMeshBg(ratio: ratio, theme: theme, scheme: scheme)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    dashboard
                        .containerRelativeFrame(.vertical)
                    historySection
                }
            }

            // Settings gear — floats top-right
            VStack {
                HStack {
                    Spacer()
                    Button { haptic(); showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(theme.ink(for: scheme).opacity(0.45))
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
        .environment(\.themeInk, theme.ink(for: scheme))
        .preferredColorScheme(appearance.colorScheme)
        .onAppear { syncWidget() }
        .onChange(of: totalCal)     { _, _ in syncWidget() }
        .onChange(of: calorieGoal)  { _, _ in syncWidget() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showLog) {
            let save: (FoodEntry) -> Void = { modelContext.insert($0) }
            LogMealView(
                gradTop: grad.0, gradBottom: grad.1, onSave: save,
                startInScanMode: startLogInScan
            )
        }
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero
            let ink = theme.ink(for: scheme)
            if newHeroStyle {
                // ── New style: coloured number + plain-english subtitle ──
                VStack(spacing: 6) {
                    Text(heroNumberNew)
                        .font(.system(size: 96, weight: .thin))
                        .monospacedDigit()
                        .tracking(-2)
                        .foregroundStyle(heroColorNew)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .contentTransition(.numericText(countsDown: balance < 0))
                        .animation(.spring(duration: 0.4), value: balance)

                    Text(heroSubtitleNew)
                        .font(.system(size: 13))
                        .foregroundStyle(heroColorNew.opacity(0.65))
                        .animation(.easeInOut(duration: 0.3), value: energyZone)
                }
            } else {
                // ── Original style: arrow + zone label + ink number ─────
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: energyZone.arrow)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ink.opacity(0.78))
                            .animation(.spring(duration: 0.4), value: energyZone)
                        Text(energyZone.label)
                            .font(.system(size: 13))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(ink.opacity(0.62))
                    }

                    Text(heroNumber)
                        .font(.system(size: 96, weight: .thin))
                        .monospacedDigit()
                        .tracking(-2)
                        .foregroundStyle(ink)
                        .shadow(color: .black.opacity(scheme == .dark ? 0.15 : 0.06), radius: 8, y: 4)
                        .contentTransition(.numericText(countsDown: balance < 0))
                        .animation(.spring(duration: 0.4), value: balance)

                    Text("goal \(Int(calorieGoal).formatted()) kcal")
                        .font(.system(size: 13))
                        .foregroundStyle(ink.opacity(0.5))
                }
            }

            // ── Hero hint ────────────────────────────────────────
            if !heroHintDismissed {
                HeroHint(ink: ink) {
                    withAnimation(.spring(duration: 0.4)) { heroHintDismissed = true }
                }
                .padding(.top, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            }

            Spacer(minLength: 36)

            BurndownCard(
                totalProtein: totalProtein,
                totalCarbs:   totalCarbs,
                totalFat:     totalFat,
                entries:      today,
                calorieGoal:  calorieGoal,
                proteinGoal:  proteinGoal,
                carbsGoal:    carbsGoal,
                fatGoal:      fatGoal
            )

            Spacer(minLength: 20)

            HStack(spacing: 10) {
                MacroBox(value: totalProtein, label: "Protein")
                MacroBox(value: totalCarbs,   label: "Carbs")
                MacroBox(value: totalFat,     label: "Fat")
            }

            Spacer(minLength: 36)

            // Log button — tap = open log, long-press (≥0.4s) = jump straight to Scan.
            // Pattern: onLongPressGesture(minimumDuration:perform:onPressingChanged:)
            // is the canonical Apple API for this. `perform` fires when 0.4s is held;
            // a separate TapGesture handles the quick-tap case. Apple uses
            // onPressingChanged for the visual press feedback (scale/opacity).
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(ink)
                .frame(width: 64, height: 64)
                .background(ink.opacity(0.18))
                .clipShape(Circle())
                .overlay(Circle().stroke(ink.opacity(0.28), lineWidth: 1.5))
                .scaleEffect(logIsPressing ? 0.92 : 1)
                .animation(.spring(duration: 0.2), value: logIsPressing)
                .contentShape(Circle())
                .onLongPressGesture(
                    minimumDuration: 0.4,
                    perform: {
                        haptic(.medium)
                        startLogInScan = true
                        showLog = true
                    },
                    onPressingChanged: { pressing in
                        logIsPressing = pressing
                    }
                )
                .simultaneousGesture(
                    // Quick tap → primary action. simultaneousGesture lets this
                    // recognize alongside the long-press; the long-press handler
                    // wins if held, and shouldDismiss prevents double-firing
                    // because `perform` already opened the sheet by then.
                    TapGesture()
                        .onEnded {
                            // Guard: if the press lasted long enough to fire the
                            // long-press, showLog is already true → no-op.
                            guard !showLog else { return }
                            haptic()
                            startLogInScan = false
                            showLog = true
                        }
                )

            Spacer(minLength: 40)
        }
        .padding(.horizontal, 22)
    }

    // MARK: - History section

    private var historySection: some View {
        let ink = theme.ink(for: scheme)
        return VStack(spacing: 12) {
            HStack {
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(ink.opacity(0.55))
                Spacer()
                if !today.isEmpty {
                    Text("\(today.count) \(today.count == 1 ? "entry" : "entries")")
                        .font(.system(size: 12))
                        .foregroundStyle(ink.opacity(0.4))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)

            if today.isEmpty {
                // 4. Empty state
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(ink.opacity(0.3))
                    Text("nothing logged yet")
                        .font(.system(size: 13))
                        .foregroundStyle(ink.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 3. Swipe-to-delete cards
                LazyVStack(spacing: 10) {
                    ForEach(today.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                        SwipeToDelete {
                            haptic(.medium)
                            withAnimation(.spring(duration: 0.3)) {
                                modelContext.delete(entry)
                            }
                        } content: {
                            EntryCard(entry: entry)
                        }
                    }
                }
                .padding(.horizontal, 22)
            }

            Spacer(minLength: 48)
        }
    }

    // MARK: - Widget sync

    private func syncWidget() {
        let ud = UserDefaults(suiteName: "group.MPIE.TimeMe")
        ud?.set(remaining,                          forKey: "caloriesRemaining")
        ud?.set(ratio,                              forKey: "ratio")
        ud?.set(calorieGoal,                        forKey: "calorieGoal")
        ud?.set(max(0, proteinGoal - totalProtein), forKey: "proteinLeft")
        ud?.set(max(0, carbsGoal   - totalCarbs),   forKey: "carbsLeft")
        ud?.set(max(0, fatGoal     - totalFat),     forKey: "fatLeft")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Energy zone

enum EnergyZone: Equatable {
    case deficit, onTrack, surplus

    var label: String {
        switch self {
        case .deficit:  return "deficit"
        case .onTrack:  return "on track"
        case .surplus:  return "surplus"
        }
    }
    var arrow: String {
        switch self {
        case .deficit:  return "arrow.down"
        case .onTrack:  return "minus"
        case .surplus:  return "arrow.up"
        }
    }
}

// MARK: - Swipe to delete wrapper

struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = 64

    var body: some View {
        ZStack(alignment: .trailing) {
            // Trash button revealed on swipe
            Button {
                withAnimation(.spring(duration: 0.25)) { onDelete() }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.red.opacity(0.85))
                    )
            }
            .scaleEffect(min(1, abs(offset) / threshold))
            .opacity(offset < -12 ? 1 : 0)
            .animation(.spring(duration: 0.2), value: offset)

            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { v in
                            guard v.translation.width < 0 else { return }
                            offset = max(v.translation.width, -threshold - 8)
                        }
                        .onEnded { v in
                            withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                                if v.translation.width < -threshold { onDelete() }
                                offset = 0
                            }
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Entry card

struct EntryCard: View {
    let entry: FoodEntry
    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.timestamp)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(timeString)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(ink.opacity(0.55))
                .frame(width: 52, alignment: .leading)

            HStack(spacing: 0) {
                MacroChip(value: entry.protein, label: "P", color: ink.opacity(0.9))
                MacroChip(value: entry.carbs,   label: "C", color: MacroPalette.carbs(for: scheme))
                MacroChip(value: entry.fat,     label: "F", color: MacroPalette.fat(for: scheme))
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories))")
                    .font(.system(size: 22, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                Text("kcal")
                    .font(.system(size: 11))
                    .foregroundStyle(ink.opacity(0.45))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(ink.opacity(0.09))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct MacroChip: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Int(value))g")
                .font(.system(size: 16, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .tracking(0.5)
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Macro box

struct MacroBox: View {
    let value: Double
    let label: String
    @Environment(\.themeInk) private var ink

    var body: some View {
        VStack(spacing: 8) {
            Text(value < 1 ? "—" : "\(Int(value))g")
                .font(.system(size: 20, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ink)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: value)
            Text(label)
                .font(.system(size: 10))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(ink.opacity(0.60))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(ink.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Hero hint

private struct HeroHint: View {
    let ink:       Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("This is your energy balance")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.85))

                Text("Log meals with **+** below. The number shows how many kcal you're under or over your daily goal.")
                    .font(.system(size: 12))
                    .foregroundStyle(ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    HintPill(icon: "arrow.down", label: "deficit",  ink: ink)
                    HintPill(icon: "minus",      label: "on track", ink: ink)
                    HintPill(icon: "arrow.up",   label: "surplus",  ink: ink)
                }
                .padding(.top, 2)
            }

            Button {
                haptic()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.45))
                    .frame(width: 22, height: 22)
                    .background(ink.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(ink.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture {
            haptic()
            onDismiss()
        }
    }
}

private struct HintPill: View {
    let icon:  String
    let label: String
    let ink:   Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(ink.opacity(0.55))
    }
}

#Preview {
    MainView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}


