//
//  TimeMeWidget.swift
//  TimeMeWidget
//
//  Created by Michael Pieniazek on 14/04/2026.
//

import AppIntents
import WidgetKit
import SwiftUI

private let kSuite  = "group.MPIE.TimeMe"
private let kGoal   = 2000.0
private let kJRatio = 4.184

// MARK: - Toggle intent

struct ToggleUnitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Unit"

    func perform() async throws -> some IntentResult {
        let ud = UserDefaults(suiteName: kSuite)
        ud?.set(!(ud?.bool(forKey: "showKJ") ?? false), forKey: "showKJ")
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeMeWidget")
        return .result()
    }
}

// MARK: - Timeline

struct FireEntry: TimelineEntry {
    let date: Date
    let kcalRemaining: Double
    let ratio: Double
    let proteinLeft: Double
    let carbsLeft: Double
    let fatLeft: Double
    let showKJ: Bool

    var kJRemaining: Double { kcalRemaining * kJRatio }
}

struct FireProvider: TimelineProvider {
    private func load() -> FireEntry {
        let ud = UserDefaults(suiteName: kSuite)
        func val(_ key: String, _ def: Double) -> Double {
            (ud?.object(forKey: key) as? Double) ?? def
        }
        let goal = val("calorieGoal", kGoal)
        return FireEntry(
            date:           .now,
            kcalRemaining:  val("caloriesRemaining", goal),
            ratio:          val("ratio", 0),
            proteinLeft:    val("proteinLeft", 150),
            carbsLeft:      val("carbsLeft", 250),
            fatLeft:        val("fatLeft", 65),
            showKJ:         ud?.bool(forKey: "showKJ") ?? false
        )
    }

    func placeholder(in context: Context) -> FireEntry {
        FireEntry(date: .now, kcalRemaining: 500, ratio: 0.75,
                  proteinLeft: 87, carbsLeft: 130, fatLeft: 32, showKJ: false)
    }
    func getSnapshot(in context: Context, completion: @escaping (FireEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FireEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [load()], policy: .after(next)))
    }
}

// MARK: - Gradient helpers

private func widgetBgColors(ratio: Double) -> [Color] {
    switch ratio {
    case ..<0.35: return [Color(red: 0.56, green: 0.71, blue: 0.91), Color(red: 0.66, green: 0.56, blue: 0.83)]
    case 0.35..<0.55: return [Color(red: 0.91, green: 0.66, blue: 0.47), Color(red: 0.94, green: 0.75, blue: 0.44)]
    case 0.55..<0.80: return [Color(red: 0.94, green: 0.56, blue: 0.31), Color(red: 0.96, green: 0.69, blue: 0.25)]
    case 0.80..<1.0:  return [Color(red: 0.91, green: 0.44, blue: 0.19), Color(red: 0.85, green: 0.31, blue: 0.13)]
    default:          return [Color(red: 0.72, green: 0.08, blue: 0.03), Color(red: 0.31, green: 0.05, blue: 0.02)]
    }
}

private func widgetFlameColor(ratio: Double) -> Color {
    switch ratio {
    case ..<0.35:
        return Color(red: 0.4, green: 0.65, blue: 1.0)
    case 0.35..<0.70:
        let t = (ratio - 0.35) / 0.35
        return Color(red: 0.4 + 0.55*t, green: 0.65 - 0.15*t, blue: 1.0 - 0.85*t)
    case 0.70..<1.0:
        let t = (ratio - 0.70) / 0.30
        return Color(red: 0.95, green: 0.50 - 0.20*t, blue: 0.15)
    default:
        return Color(red: 1.0, green: 0.55, blue: 0.50)
    }
}

// MARK: - Small widget

struct SmallFireView: View {
    let entry: FireEntry

    // Surplus = eaten over goal (positive = over)
    private var isSurplus: Bool { entry.kcalRemaining < 0 }

    private var stateLabel: String { isSurplus ? "Surplus" : "Deficit" }

    private var stateDescription: String {
        switch entry.ratio {
        case ..<0.25: return "Great start"
        case 0.25..<0.50: return "Making progress"
        case 0.50..<0.75: return "Halfway there"
        case 0.75..<0.90: return "Almost at goal"
        case 0.90..<1.0:  return "Close to goal"
        case 1.0..<1.10:  return "Just over goal"
        default:          return "Over goal"
        }
    }

    private var bigNumber: String {
        let val = entry.showKJ ? entry.kJRemaining : entry.kcalRemaining
        let abs = Int(Swift.abs(val))
        return abs.formatted()
    }

    private var unit: String { entry.showKJ ? "kJ" : "kcal" }

    var body: some View {
        Button(intent: ToggleUnitIntent()) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header: state + icon ──────────────────────────
                HStack(spacing: 5) {
                    Image(systemName: isSurplus ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(stateLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                // ── Big number ────────────────────────────────────
                Text(bigNumber)
                    .font(.system(size: 44, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // ── Unit ─────────────────────────────────────────
                Text(unit)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 1)

                // ── State description ─────────────────────────────
                Text(stateDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 3)

                Spacer()

                // ── Macro footer: P · C · F ───────────────────────
                HStack(spacing: 12) {
                    MacroFooterItem(letter: "P", value: entry.proteinLeft)
                    MacroFooterItem(letter: "C", value: entry.carbsLeft)
                    MacroFooterItem(letter: "F", value: entry.fatLeft)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

private struct MacroFooterItem: View {
    let letter: String
    let value: Double
    var body: some View {
        HStack(spacing: 3) {
            Text(letter)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            Text("\(Int(max(0, value)))g")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
        .fixedSize()
    }
}

// MARK: - Medium widget

struct MediumFireView: View {
    let entry: FireEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left — flame + calories (same as small)
            Button(intent: ToggleUnitIntent()) {
                VStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(widgetFlameColor(ratio: entry.ratio))
                        .shadow(color: widgetFlameColor(ratio: entry.ratio).opacity(0.6), radius: 4)

                    let primary = entry.showKJ
                        ? "\(Int(max(0, entry.kJRemaining)))"
                        : "\(Int(max(0, entry.kcalRemaining)))"
                    let unit = entry.showKJ ? "kj left" : "kcal left"
                    let secondary = entry.showKJ
                        ? "\(Int(max(0, entry.kcalRemaining))) kcal"
                        : "\(Int(max(0, entry.kJRemaining))) kj"

                    Text(primary)
                        .font(.system(size: 32, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 8))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(secondary)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 2)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 12)

            // Right — macro numbers, clean and simple
            VStack(alignment: .leading, spacing: 10) {
                MacroNumRow(label: "Protein", value: entry.proteinLeft, color: .white.opacity(0.9))
                MacroNumRow(label: "Carbs",   value: entry.carbsLeft,   color: Color(red: 1, green: 0.85, blue: 0.63))
                MacroNumRow(label: "Fat",     value: entry.fatLeft,     color: Color(red: 0.67, green: 0.94, blue: 0.78))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MacroNumRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(Int(max(0, value)))g")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Entry point

struct FireWidgetView: View {
    let entry: FireEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemMedium { MediumFireView(entry: entry) }
        else                       { SmallFireView(entry: entry)  }
    }
}

struct TimeMeWidget: Widget {
    let kind: String = "TimeMeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FireProvider()) { entry in
            FireWidgetView(entry: entry)
                // Gradient lives here — this is what fills the widget edge-to-edge
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: widgetBgColors(ratio: entry.ratio),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Calories Left")
        .description("Tap to switch between kcal and kJ.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    TimeMeWidget()
} timeline: {
    FireEntry(date: .now, kcalRemaining: 947,  ratio: 0.53, proteinLeft: 87,  carbsLeft: 130, fatLeft: 32, showKJ: false)
    FireEntry(date: .now, kcalRemaining: 947,  ratio: 0.53, proteinLeft: 87,  carbsLeft: 130, fatLeft: 32, showKJ: true)
    FireEntry(date: .now, kcalRemaining: 100,  ratio: 0.95, proteinLeft: 5,   carbsLeft: 10,  fatLeft: 3,  showKJ: false)
    FireEntry(date: .now, kcalRemaining: -200, ratio: 1.10, proteinLeft: 0,   carbsLeft: 0,   fatLeft: 0,  showKJ: false)
}

#Preview(as: .systemMedium) {
    TimeMeWidget()
} timeline: {
    FireEntry(date: .now, kcalRemaining: 947, ratio: 0.53, proteinLeft: 87, carbsLeft: 130, fatLeft: 32, showKJ: false)
}
