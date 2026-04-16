// ─────────────────────────────────────────────────────────────
// SettingsView.swift
// ⚠️  DevSection is DEV ONLY — safe to remove before App Store release
// ─────────────────────────────────────────────────────────────

import SwiftUI
import SwiftData

// MARK: - Settings

struct SettingsView: View {
    @Environment(\.dismiss)          private var dismiss
    @AppStorage("gradientTheme")     private var themeRawValue:      String = GradientTheme.fire.rawValue
    @AppStorage("calorieGoal")       private var calorieGoal:        Double = 2000
    @AppStorage("themeAppearance")   private var appearanceRawValue: String = ThemeAppearance.auto.rawValue

    private var selectedTheme: GradientTheme {
        GradientTheme(rawValue: themeRawValue) ?? .fire
    }
    private var selectedAppearance: ThemeAppearance {
        ThemeAppearance(rawValue: appearanceRawValue) ?? .auto
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Daily goal ───────────────────────────────────
                Section {
                    GoalRow(
                        label: "Daily calorie goal",
                        value: $calorieGoal,
                        unit: "kcal",
                        range: 800...5000,
                        step: 50
                    )
                } header: {
                    Text("Energy Goal")
                } footer: {
                    Text("Used to calculate your deficit or surplus throughout the day. A 500 kcal daily deficit ≈ 0.5 kg/week loss.")
                        .foregroundStyle(.secondary)
                }

                // ── Appearance (Auto / Light / Dark) ─────────────
                Section {
                    Picker("Appearance", selection: $appearanceRawValue) {
                        ForEach(ThemeAppearance.allCases) { a in
                            Text(a.displayName).tag(a.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Automatic follows the system setting. Each colour theme has tuned palettes for both modes.")
                        .foregroundStyle(.secondary)
                }

                // ── Theme picker ─────────────────────────────────
                Section {
                    ThemeGrid(selectedTheme: selectedTheme,
                              appearance:    selectedAppearance) { theme in
                        haptic()
                        themeRawValue = theme.rawValue
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("Colour Theme")
                } footer: {
                    Text("Changes the animated background across the whole app.")
                        .foregroundStyle(.secondary)
                }

                // ── ⚠️ DEV ONLY — delete this Section before release ──
                Section {
                    DevSection()
                } header: {
                    Label("Developer", systemImage: "hammer.fill")
                } footer: {
                    Text("⚠️  Remove before release.")
                        .foregroundStyle(.orange)
                }
                // ── END DEV ONLY ─────────────────────────────────────
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Goal row

private struct GoalRow: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            // Minus
            Button {
                haptic()
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("\(Int(value)) \(unit)")
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .frame(minWidth: 90, alignment: .center)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: value)

            // Plus
            Button {
                haptic()
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Theme grid

private struct ThemeGrid: View {
    let selectedTheme: GradientTheme
    let appearance:    ThemeAppearance
    let onSelect: (GradientTheme) -> Void

    @Environment(\.colorScheme) private var systemScheme

    private var previewScheme: ColorScheme {
        appearance.colorScheme ?? systemScheme
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(GradientTheme.allCases) { theme in
                ThemeSwatch(theme: theme,
                            scheme: previewScheme,
                            isSelected: theme == selectedTheme)
                    .onTapGesture { onSelect(theme) }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeSwatch: View {
    let theme: GradientTheme
    let scheme: ColorScheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: theme.previewColors(for: scheme),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1.6, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2.5)
                )
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(6)
                    }
                }

            Text(theme.displayName)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
    }
}

// MARK: - ⚠️ DEV ONLY — delete this struct before release

private struct DevSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @AppStorage("newHeroStyle")      private var newHeroStyle:      Bool   = false
    @AppStorage("heroHintDismissed") private var heroHintDismissed: Bool   = false
    @State private var confirmToday = false
    @State private var confirmAll   = false

    private var todayCount: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.timestamp >= start }.count
    }

    var body: some View {
        // ── UI experiments ────────────────────────────────────
        Toggle(isOn: $newHeroStyle) {
            Label("New hero style", systemImage: "sparkles")
        }

        // ── Haptic lab ────────────────────────────────────────
        // Page lives in HapticLab.swift — drop that single file into any project.
        NavigationLink {
            HapticLabView()
        } label: {
            Label("Haptic lab", systemImage: "waveform")
        }

        // ── Hints reset ───────────────────────────────────────
        Button {
            heroHintDismissed = false
        } label: {
            Label("Reset hints", systemImage: "questionmark.bubble")
        }

        // ── Mock data ─────────────────────────────────────────
        Button {
            seedMockData()
        } label: {
            Label("Seed mock day (12 hr)", systemImage: "wand.and.stars")
        }

        // ── Reset today ───────────────────────────────────────
        Button(role: .destructive) {
            confirmToday = true
        } label: {
            HStack {
                Label("Reset today", systemImage: "arrow.counterclockwise")
                Spacer()
                Text("\(todayCount) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            "Delete \(todayCount) entries from today?",
            isPresented: $confirmToday,
            titleVisibility: .visible
        ) {
            Button("Reset today", role: .destructive) { resetToday() }
        }

        // ── Reset all ─────────────────────────────────────────
        Button(role: .destructive) {
            confirmAll = true
        } label: {
            Label("Reset all data", systemImage: "trash")
        }
        .confirmationDialog(
            "Delete all \(allEntries.count) entries forever?",
            isPresented: $confirmAll,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { resetAll() }
        }
    }

    // MARK: - Mock data generation

    private func seedMockData() {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: .now)

        // Realistic meal archetypes: (hour offset, name hint, protein, carbs, fat)
        let meals: [(Double, Double, Double, Double)] = [
            // ~7am  breakfast
            (7.2,  25, 45, 12),
            // ~9am  coffee + snack
            (9.1,   8, 30,  6),
            // ~12pm lunch
            (12.3, 40, 60, 18),
            // ~3pm  afternoon snack
            (15.0, 12, 35,  8),
            // ~6pm  dinner
            (18.4, 50, 70, 22),
            // ~8pm  dessert / evening snack
            (20.1, 10, 55, 14),
        ]

        for (hourOffset, protein, carbs, fat) in meals {
            // Add ±15 min jitter so the chart looks natural
            let jitter = Double.random(in: -0.25...0.25)
            let ts = cal.date(byAdding: .second,
                              value: Int((hourOffset + jitter) * 3600),
                              to: start)!

            let entry = FoodEntry(
                timestamp: ts,
                protein:   protein + Double.random(in: -5...5),
                carbs:     carbs   + Double.random(in: -8...8),
                fat:       fat     + Double.random(in: -3...3)
            )
            modelContext.insert(entry)
        }
    }

    private func resetToday() {
        let start = Calendar.current.startOfDay(for: .now)
        allEntries.filter { $0.timestamp >= start }.forEach { modelContext.delete($0) }
    }

    private func resetAll() {
        allEntries.forEach { modelContext.delete($0) }
    }
}
