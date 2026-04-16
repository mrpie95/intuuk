import SwiftUI

// MARK: - Active macro for fine-tune sheet

enum ActiveMacro: String, Identifiable {
    case protein, carbs, fat
    var id: String { rawValue }

    var label: String {
        switch self {
        case .protein: return "Protein"
        case .carbs:   return "Carbs"
        case .fat:     return "Fat"
        }
    }
    var color: Color {
        switch self {
        case .protein: return .white.opacity(0.9)
        case .carbs:   return Color(hex: "FFD7A0")
        case .fat:     return Color(hex: "AAF0C8")
        }
    }
    var range: ClosedRange<Double> {
        switch self {
        case .protein: return 0...300
        case .carbs:   return 0...500
        case .fat:     return 0...150
        }
    }
    var step: Double {
        switch self {
        case .protein: return 1
        case .carbs:   return 1
        case .fat:     return 1
        }
    }
    var quickSteps: [Double] {
        switch self {
        case .protein: return [10, 25, 50]
        case .carbs:   return [20, 50, 100]
        case .fat:     return [5,  15,  30]
        }
    }
}

// MARK: - Log view mode (dev toggle)

enum LogViewMode: String, CaseIterable {
    case classic = "classic"
    case unified = "unified"
    case receipt = "receipt"

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .unified: return "Unified"
        case .receipt: return "Receipt"
        }
    }
}

// MARK: - Meal ingredient (used by IngredientsLogView)

struct MealIngredient: Identifiable {
    let id      = UUID()
    var label:   String
    var emoji:   String
    var protein: Double
    var carbs:   Double
    var fat:     Double
    var kcal: Double { protein * 4 + carbs * 4 + fat * 9 }
}

// MARK: - Macro layer (shared by Angle 1 & 2)

struct MacroLayer: Identifiable {
    let id    = UUID()
    let emoji: String
    let label: String
    var p:     Double
    var c:     Double
    var f:     Double
    var kcal: Double { p * 4 + c * 4 + f * 9 }
}

// MARK: - Scale mode

enum ScaleMode: String, CaseIterable {
    case weight   = "Weight"
    case servings = "Servings"

    var icon: String {
        switch self {
        case .weight:   return "scalemass.fill"
        case .servings: return "fork.knife"
        }
    }
}

// MARK: - Log food view

struct LogFoodView: View {
    @Environment(\.dismiss)     private var dismiss
    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme
    @AppStorage("logViewMode") private var logViewMode: String = LogViewMode.classic.rawValue

    let gradTop: Color
    let gradBottom: Color
    let onSave: (FoodEntry) -> Void

    @State private var protein: Double = 0
    @State private var carbs:   Double = 0
    @State private var fat:     Double = 0
    @State private var activeMacro: ActiveMacro? = nil
    @State private var confirmed      = false
    @State private var showScanner    = false
    @State private var showQuickAdd   = false

    // ── Opt-in scaler ────────────────────────────────────────
    @State private var useScaling:        Bool      = false
    @State private var scaleMode:         ScaleMode = .weight
    @State private var basisGrams:        Double    = 100
    @State private var amount:            Double    = 100
    @State private var servingMultiplier: Double    = 1.0

    private var scale: Double {
        guard useScaling else { return 1.0 }
        switch scaleMode {
        case .weight:   return basisGrams > 0 ? amount / basisGrams : 1.0
        case .servings: return servingMultiplier
        }
    }
    private var displayProtein: Double { protein * scale }
    private var displayCarbs:   Double { carbs   * scale }
    private var displayFat:     Double { fat     * scale }
    private var kcal: Double { displayProtein * 4 + displayCarbs * 4 + displayFat * 9 }

    private func binding(for macro: ActiveMacro) -> Binding<Double> {
        switch macro {
        case .protein: return $protein
        case .carbs:   return $carbs
        case .fat:     return $fat
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [gradTop, gradBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("What did you eat?")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(ink)
                    Text("tap to add  ·  hold to fine-tune")
                        .font(.system(size: 13))
                        .foregroundStyle(ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 28)

                // ── Macro log card ────────────────────────────────
                MacroLogCard(
                    protein: $protein,
                    carbs: $carbs,
                    fat: $fat,
                    onLongPress: { macro in
                        haptic()
                        activeMacro = macro
                    }
                )
                .padding(.horizontal, 18)

                // ── Scale toggle / amount adjuster ───────────────
                if useScaling {
                    AmountAdjusterCard(
                        basisGrams:        basisGrams,
                        amount:            $amount,
                        scaleMode:         $scaleMode,
                        servingMultiplier: $servingMultiplier
                    ) {
                        // Bake the current scale into the raw macro values, then
                        // reset to a clean "per 100 g / ×1" baseline.
                        let s = scale
                        protein           *= s
                        carbs             *= s
                        fat               *= s
                        basisGrams         = 100
                        amount             = 100
                        servingMultiplier  = 1.0
                        withAnimation(.spring(duration: 0.3)) { useScaling = false }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    HStack {
                        Button {
                            haptic()
                            withAnimation(.spring(duration: 0.35)) { useScaling = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "scalemass.fill")
                                    .font(.system(size: 11))
                                Text("Scale by weight or servings")
                                    .font(.system(size: 13))
                            }
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.08))
                            .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .transition(.opacity)
                }

                Spacer(minLength: 16)

                // ── Action cards (scan + quick-add) ──────────────
                HStack(spacing: 10) {
                    ActionCard(
                        icon:     "camera.viewfinder",
                        title:    "Scan label",
                        subtitle: kcal > 0 ? "adds to meal" : "point at nutrition facts"
                    ) { haptic(); showScanner = true }

                    ActionCard(
                        icon:     "fork.knife",
                        title:    "Quick add",
                        subtitle: "chicken, rice, butter…"
                    ) { haptic(); showQuickAdd = true }
                }
                .padding(.horizontal, 18)

                Spacer(minLength: 16)

                // ── kcal preview ──────────────────────────────────
                KcalPreview(kcal: kcal, protein: displayProtein, carbs: displayCarbs, fat: displayFat)
                    .padding(.horizontal, 18)

                Spacer(minLength: 16)

                // ── Eaten button ──────────────────────────────────
                Button {
                    guard kcal > 0 else { return }
                    haptic(.medium)
                    onSave(FoodEntry(protein: displayProtein, carbs: displayCarbs, fat: displayFat))
                    withAnimation { confirmed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                } label: {
                    Text(confirmed ? "✓  logged" : "Eaten")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(kcal > 0 ? .black.opacity(0.85) : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(kcal > 0 ? .white.opacity(confirmed ? 1.0 : 0.93) : .white.opacity(0.12))
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.2), value: confirmed)
                        .animation(.easeInOut(duration: 0.2), value: kcal > 0)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
        }
        // Per-macro fine-tune sheet
        .sheet(item: $activeMacro) { macro in
            MacroFocusSheet(macro: macro, value: binding(for: macro))
                .presentationDetents([.height(300)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        // Scanner sheet — fills macros + auto-enables scaler
        // Quick-add food shelf
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet { addP, addC, addF in
                // If the scaler is active, bake its current multiplier into the
                // raw values first — otherwise the quick-add foods would also get
                // scaled (e.g. scanned curry at 300g would triple the rice too).
                if useScaling {
                    let s = scale
                    protein          *= s
                    carbs            *= s
                    fat              *= s
                    basisGrams        = 100
                    amount            = 100
                    servingMultiplier = 1.0
                    withAnimation(.spring(duration: 0.3)) { useScaling = false }
                }
                protein += addP
                carbs   += addC
                fat     += addF
            }
            .presentationDetents([.large])
            .presentationCornerRadius(32)
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showScanner) {
            FoodScannerView { p, c, f, basis in
                // Replace everything with the scanned values.
                protein    = p
                carbs      = c
                fat        = f
                basisGrams = basis
                amount     = 100
                withAnimation(.spring(duration: 0.4)) { useScaling = true }
            }
        }
    }
}

// MARK: - Macro log card

struct MacroLogCard: View {
    @Binding var protein: Double
    @Binding var carbs:   Double
    @Binding var fat:     Double
    let onLongPress: (ActiveMacro) -> Void

    var body: some View {
        VStack(spacing: 0) {
            MacroLogRow(label: "Protein", macro: .protein, pills: ActiveMacro.protein.quickSteps,
                        value: $protein, accentColor: ActiveMacro.protein.color,
                        onLongPress: { onLongPress(.protein) })
            Divider().overlay(.white.opacity(0.1))
            MacroLogRow(label: "Carbs",   macro: .carbs,   pills: ActiveMacro.carbs.quickSteps,
                        value: $carbs,   accentColor: ActiveMacro.carbs.color,
                        onLongPress: { onLongPress(.carbs) })
            Divider().overlay(.white.opacity(0.1))
            MacroLogRow(label: "Fat",     macro: .fat,     pills: ActiveMacro.fat.quickSteps,
                        value: $fat,     accentColor: ActiveMacro.fat.color,
                        onLongPress: { onLongPress(.fat) })
        }
        .padding(.vertical, 6)
        .background(.white.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct MacroLogRow: View {
    let label: String
    let macro: ActiveMacro
    let pills: [Double]
    @Binding var value: Double
    let accentColor: Color
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text(String(format: "%.1f", value) + "g")
                    .font(.system(size: 24, weight: .medium))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: value)
            }
            .frame(width: 92, alignment: .leading)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) { onLongPress() }

            HStack(spacing: 8) {
                ForEach(pills, id: \.self) { amt in
                    Button {
                        haptic()
                        value = max(0, value + amt)
                    } label: {
                        Text("+\(Int(amt))")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.15))
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                haptic()
                value = max(0, value - pills[0])
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

// MARK: - Per-macro fine-tune sheet

struct MacroFocusSheet: View {
    let macro: ActiveMacro
    @Binding var value: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle area
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Macro label
            Text(macro.label)
                .font(.system(size: 13, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(macro.color.opacity(0.8))

            // Big value
            HStack(alignment: .center, spacing: 20) {
                // Minus
                Button {
                    haptic()
                    value = max(0, value - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                        .frame(width: 48, height: 48)
                        .background(.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Value display
                Text(String(format: "%.1f", value))
                    .font(.system(size: 72, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(macro.color)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: value)
                    .frame(minWidth: 120)

                // Plus
                Button {
                    haptic()
                    value = min(macro.range.upperBound, value + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                        .frame(width: 48, height: 48)
                        .background(.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)

            Text("grams")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            // Slider
            Slider(value: $value, in: macro.range, step: macro.step)
                .tint(macro.color)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - kcal preview

struct KcalPreview: View {
    let kcal: Double
    let protein: Double
    let carbs:   Double
    let fat:     Double

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kcal < 1 ? "0" : "\(Int(kcal))")
                    .font(.system(size: 52, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: kcal)
                Text("kcal")
                    .font(.system(size: 13))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if kcal < 1 {
                Text("add macros\nabove to preview")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.trailing)
            } else {
                VStack(alignment: .trailing, spacing: 6) {
                    MacroMiniChip(value: protein, label: "P", color: .white.opacity(0.85))
                    MacroMiniChip(value: carbs,   label: "C", color: Color(hex: "FFD7A0"))
                    MacroMiniChip(value: fat,     label: "F", color: Color(hex: "AAF0C8"))
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .background(.white.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.14), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct MacroMiniChip: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(color.opacity(0.6))
            Text(String(format: "%.1f", value) + "g")
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

// MARK: - Amount adjuster card (shared by manual + scanner paths)

struct AmountAdjusterCard: View {
    let basisGrams:        Double
    @Binding var amount:            Double
    @Binding var scaleMode:         ScaleMode
    @Binding var servingMultiplier: Double
    let onClose: () -> Void

    // Weight mode
    private let weightChips:  [Double] = [100, 150, 200, 300]
    private let sliderRange:  ClosedRange<Double> = 50...500

    // Servings mode
    private let servingChips: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0]
    private let servingStep:  Double   = 0.25
    private let servingMax:   Double   = 10.0

    // ── Display helpers ──────────────────────────────────────

    private var headerAmount: String {
        scaleMode == .weight
            ? "\(Int(amount))"
            : servingDisplay(servingMultiplier)
    }
    private var headerUnit: String {
        scaleMode == .weight ? "g" : "×"
    }
    private var headerContext: String {
        scaleMode == .weight
            ? "per \(Int(basisGrams))g"
            : "per serving"
    }
    private var headerIcon: String { scaleMode.icon }

    private func servingDisplay(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(v))"
            : String(format: "%.2f", v)
    }
    private func servingChipLabel(_ v: Double) -> String {
        switch v {
        case 0.25: return "¼"
        case 0.5:  return "½"
        case 0.75: return "¾"
        case 1.0:  return "1"
        case 1.5:  return "1½"
        case 2.0:  return "2"
        case 3.0:  return "3"
        default:   return String(format: "%.2g", v)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header row: readout + context + close ──────────
            HStack(alignment: .firstTextBaseline, spacing: 10) {

                // Big number animates between modes
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(headerAmount)
                        .font(.system(size: 32, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.2),
                                   value: scaleMode == .weight ? amount : servingMultiplier)
                    Text(headerUnit)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text("·")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.25))

                HStack(spacing: 4) {
                    Image(systemName: headerIcon)
                        .font(.system(size: 10))
                    Text(headerContext)
                        .font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // ── Mode switcher ─────────────────────────────────
            HStack(spacing: 0) {
                ForEach(ScaleMode.allCases, id: \.self) { mode in
                    Button {
                        haptic()
                        withAnimation(.spring(duration: 0.3)) { scaleMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12,
                                          weight: scaleMode == mode ? .semibold : .medium))
                            .foregroundStyle(scaleMode == mode
                                             ? .black.opacity(0.8)
                                             : .white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(scaleMode == mode ? .white : .clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.25), value: scaleMode)
                }
            }
            .padding(3)
            .background(.white.opacity(0.10))
            .clipShape(Capsule())

            // ── Mode-specific controls ────────────────────────
            if scaleMode == .weight {
                weightControls
            } else {
                servingsControls
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.white.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.14), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Weight controls

    private var weightControls: some View {
        VStack(spacing: 10) {
            // Quick gram chips
            HStack(spacing: 8) {
                ForEach(weightChips, id: \.self) { chip in
                    let selected = amount == chip
                    Button {
                        haptic()
                        withAnimation(.spring(duration: 0.25)) { amount = chip }
                    } label: {
                        Text("\(Int(chip))g")
                            .font(.system(size: 13, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? .black.opacity(0.85) : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? .white : .white.opacity(0.15))
                            .overlay(Capsule().stroke(.white.opacity(selected ? 0 : 0.18), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.2), value: selected)
                }
            }

            // Momentum ruler
            RulerSlider(value: $amount, range: sliderRange)
                .frame(height: 48)
        }
    }

    // MARK: Servings controls

    private var servingsControls: some View {
        VStack(spacing: 14) {
            // Quick serving chips
            HStack(spacing: 8) {
                ForEach(servingChips, id: \.self) { chip in
                    let selected = servingMultiplier == chip
                    Button {
                        haptic()
                        withAnimation(.spring(duration: 0.25)) { servingMultiplier = chip }
                    } label: {
                        Text(servingChipLabel(chip))
                            .font(.system(size: 13, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? .black.opacity(0.85) : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? .white : .white.opacity(0.15))
                            .overlay(Capsule().stroke(.white.opacity(selected ? 0 : 0.18), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.2), value: selected)
                }
            }

            // Fine-tune ±0.25 stepper
            HStack(spacing: 0) {
                Button {
                    haptic()
                    withAnimation(.spring(duration: 0.2)) {
                        servingMultiplier = max(servingStep,
                            (servingMultiplier * 4).rounded() / 4 - servingStep)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 20)
                    .overlay(.white.opacity(0.18))

                Text("¼ serving steps")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 20)
                    .overlay(.white.opacity(0.18))

                Button {
                    haptic()
                    withAnimation(.spring(duration: 0.2)) {
                        servingMultiplier = min(servingMax,
                            (servingMultiplier * 4).rounded() / 4 + servingStep)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 40)
            .background(.white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Horizontal ruler slider
//
// Modeled on the Apple Health weight picker. Backed by UIScrollView (not SwiftUI's
// ScrollView) because we need real control over:
//   • `decelerationRate` — SwiftUI doesn't expose this, so flicks feel light
//   • the snap behaviour — we snap to ticks ourselves after deceleration finishes
//     instead of using `.viewAligned`, which tends to kill momentum on release
//
// Tick hierarchy:
//   · every 1 g  → faint hairline
//   · every 5 g  → slightly taller
//   · every 10 g → taller still
//   · every 50 g → tall + numeric label underneath

private struct RulerSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @Environment(\.themeInk) private var ink

    var body: some View {
        ZStack {
            RulerScrollView(value: $value, range: range, ink: ink)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white, location: 0.10),
                            .init(color: .white, location: 0.90),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            // Centre indicator — static, drawn above the scroll view.
            Rectangle()
                .fill(ink)
                .frame(width: 2, height: 30)
                .offset(y: -6)
                .shadow(color: .black.opacity(0.25), radius: 2)
                .allowsHitTesting(false)
        }
    }
}

// MARK: · UIScrollView-backed tick tape

private struct RulerScrollView: UIViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let ink: Color

    /// Pixels between adjacent 1 g ticks. Larger = more physical distance per gram,
    /// so each drag "weighs" more. 10 pt lets a 100 g sweep take a full 1 000 pt —
    /// enough that flicking feels like throwing a weight scale, not a slider knob.
    private let tickSpacing: CGFloat = 10

    /// Deceleration rate for the scroll view. iOS defaults:
    ///   · `.normal` = 0.998    (standard list scroll)
    ///   · `.fast`   = 0.99     (paging-style, stops quickly)
    /// Going **higher** than normal means less friction per frame → more momentum.
    /// 0.9985 is notably heavier than default, closer to a physical dial.
    private let decelerationRate: CGFloat = 0.9985

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.backgroundColor = .clear
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator   = false
        sv.decelerationRate = UIScrollView.DecelerationRate(rawValue: decelerationRate)
        sv.delegate         = context.coordinator
        sv.clipsToBounds    = false
        sv.alwaysBounceHorizontal = true

        let content = RulerTickView(
            range:       range,
            tickSpacing: tickSpacing,
            ink:         UIColor(ink)
        )
        sv.addSubview(content)

        context.coordinator.attach(scroll: sv, content: content)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateInk(UIColor(ink))
        context.coordinator.layoutIfNeeded()
        context.coordinator.syncFromBinding()
        // On first appearance (e.g. inside an expand animation) the scroll view
        // bounds are still zero.  Poll until UIKit has laid out the frame.
        if sv.contentSize.width == 0 {
            context.coordinator.scheduleLayoutSync()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: Coordinator · owns scroll state and binding sync

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: RulerScrollView
        weak var scroll:  UIScrollView?
        weak var content: RulerTickView?

        /// Last committed snap position, always a multiple of `snapStep` (in 1 g ticks
        /// from the range lower bound). Starts at Int.min so the first scroll event
        /// can initialise it without firing a spurious haptic.
        private var lastIndex: Int = Int.min

        private let haptic = UISelectionFeedbackGenerator()

        /// True while we're programmatically driving the offset (chip tap, snap anim).
        /// Suppresses the binding write-back during the animation to avoid loops.
        private var drivingProgrammatically = false

        // ── Snap / ratchet constants ─────────────────────────────────────────
        /// Value granularity: the ruler snaps to multiples of this (in grams).
        private let snapStep: Int = 5
        /// How far past the midpoint to the *next* snap we must drag before
        /// committing.  0.65 means 65 % of the 5 g gap = 3.25 g of dead-zone on
        /// each side, so a light nudge won't jump but a deliberate push does.
        private let hysteresis: CGFloat = 0.65

        init(parent: RulerScrollView) {
            self.parent = parent
            super.init()
            haptic.prepare()
        }

        func attach(scroll: UIScrollView, content: RulerTickView) {
            self.scroll = scroll
            self.content = content
        }

        func updateInk(_ color: UIColor) {
            guard let ct = content, ct.ink != color else { return }
            ct.ink = color
        }

        /// Size the scroll content and set left/right insets so tick 0 and tick N
        /// can both reach the centre indicator.
        func layoutIfNeeded() {
            guard let sv = scroll, let ct = content, sv.bounds.width > 0 else { return }
            let count = CGFloat(Int(parent.range.upperBound - parent.range.lowerBound) + 1)
            let totalW = count * parent.tickSpacing
            ct.frame = CGRect(x: 0, y: 0, width: totalW, height: sv.bounds.height)
            sv.contentSize = ct.frame.size

            let hInset = sv.bounds.width / 2 - parent.tickSpacing / 2
            if sv.contentInset.left != hInset {
                sv.contentInset = UIEdgeInsets(top: 0, left: hInset, bottom: 0, right: hInset)
                let target = targetOffset(for: parent.value, sv: sv)
                sv.setContentOffset(CGPoint(x: target, y: 0), animated: false)
                lastIndex = snapped5Index(for: parent.value)
            }
        }

        /// Called from `updateUIView` — drives the scroll view to match the binding
        /// when the binding changes externally (e.g. chip taps, normalise-on-close).
        func syncFromBinding() {
            guard let sv = scroll, !sv.isTracking, !sv.isDecelerating else { return }
            let target = targetOffset(for: parent.value, sv: sv)
            if abs(sv.contentOffset.x - target) > 0.5 {
                drivingProgrammatically = true
                sv.setContentOffset(CGPoint(x: target, y: 0), animated: true)
            }
        }

        /// Polls until the scroll view has real bounds (it may still be animating in
        /// when `updateUIView` first fires), then positions the ruler correctly.
        /// Tries every 30 ms for up to ~360 ms — enough to cover any spring animation.
        func scheduleLayoutSync(attempt: Int = 0) {
            guard attempt < 12, let sv = scroll else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                guard let self else { return }
                if sv.bounds.width > 0 {
                    self.layoutIfNeeded()
                    self.syncFromBinding()
                } else {
                    self.scheduleLayoutSync(attempt: attempt + 1)
                }
            }
        }

        // MARK: UIScrollViewDelegate

        func scrollViewDidScroll(_ sv: UIScrollView) {
            // Scroll view hasn't been laid out yet — any offset here is meaningless
            // (UIKit clamps to 0, which maps to the range minimum, not the binding value).
            // Suppress all write-back until we have real bounds.
            guard sv.bounds.width > 0, sv.contentSize.width > 0 else { return }

            let raw   = rawFractionalIndex(from: sv.contentOffset.x, sv: sv)
            let step  = CGFloat(snapStep)

            // First event: initialise without haptic.
            if lastIndex == Int.min {
                lastIndex = nearestSnap5(raw: raw)
                return
            }

            // ── Hysteresis / ratchet ─────────────────────────────────────────
            // We only commit to a new 5 g mark once the tape has crossed
            // `hysteresis × snapStep` ticks *past* the midpoint to that mark.
            // This gives a deliberate resistance that stops accidental jumps.
            let advanceThreshold = CGFloat(lastIndex) + step * hysteresis
            let retreatThreshold = CGFloat(lastIndex) - step * hysteresis

            let newIndex: Int
            if raw >= advanceThreshold {
                // Crossed far enough forward — jump to next (or further) 5 g mark.
                newIndex = min(nearestSnap5(raw: raw, rule: .up),
                               Int(parent.range.upperBound - parent.range.lowerBound))
            } else if raw <= retreatThreshold {
                // Crossed far enough backward.
                newIndex = max(nearestSnap5(raw: raw, rule: .down), 0)
            } else {
                return  // inside dead-zone — hold current snap
            }

            guard newIndex != lastIndex else { return }
            lastIndex = newIndex

            if !drivingProgrammatically && (sv.isTracking || sv.isDecelerating) {
                haptic.selectionChanged()
            }

            let newValue = Double(Int(parent.range.lowerBound) + newIndex)
            if !drivingProgrammatically, newValue != parent.value {
                parent.value = newValue
            }
        }

        /// Non-linear flick amplifier. Called right as the finger lifts — UIScrollView
        /// has already calculated where it *would* naturally decelerate to, and lets
        /// us push that target further via `targetContentOffset`.
        ///
        /// Velocity comes in as pts/ms along the scroll axis.
        ///   · slow drag  (|v| ≤ baseline) → no boost; pure 1:1 scroll physics
        ///   · hard flick (|v| large)      → boost grows with v², so "just a bit
        ///                                    harder" sends the tape much further
        func scrollViewWillEndDragging(_ sv: UIScrollView,
                                        withVelocity velocity: CGPoint,
                                        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let v    = velocity.x
            let absV = abs(v)
            let baseline: CGFloat = 0.6
            let extra = max(0, absV - baseline)
            let boost = extra * extra * 180
            guard boost > 0 else { return }

            let direction: CGFloat = v >= 0 ? 1 : -1
            var target = targetContentOffset.pointee.x + boost * direction

            let minX = -sv.contentInset.left
            let maxX =  sv.contentSize.width + sv.contentInset.right - sv.bounds.width
            target = min(max(target, minX), maxX)
            targetContentOffset.pointee.x = target
        }

        func scrollViewDidEndDragging(_ sv: UIScrollView, willDecelerate d: Bool) {
            if !d { snapToNearestTick(sv) }
        }

        func scrollViewDidEndDecelerating(_ sv: UIScrollView) {
            snapToNearestTick(sv)
        }

        func scrollViewDidEndScrollingAnimation(_ sv: UIScrollView) {
            drivingProgrammatically = false
            // Re-anchor lastIndex to wherever the animation settled so the next
            // drag starts from the right hysteresis baseline.
            let raw = rawFractionalIndex(from: sv.contentOffset.x, sv: sv)
            lastIndex = nearestSnap5(raw: raw)
        }

        // MARK: Helpers

        private func tickIndex(for value: Double) -> Int {
            Int((value - parent.range.lowerBound).rounded())
        }

        /// Index (in 1 g ticks from range.lowerBound) rounded to the nearest
        /// `snapStep` multiple, clamped to the valid range.
        private func snapped5Index(for value: Double) -> Int {
            let raw = Double(tickIndex(for: value))
            let maxIndex = Int(parent.range.upperBound - parent.range.lowerBound)
            let s = Int((raw / Double(snapStep)).rounded()) * snapStep
            return min(max(0, s), maxIndex)
        }

        /// Continuous (fractional) tick position for a given content offset.
        private func rawFractionalIndex(from offsetX: CGFloat, sv: UIScrollView) -> CGFloat {
            (offsetX + sv.contentInset.left) / parent.tickSpacing
        }

        /// Round a fractional tick position to the nearest `snapStep` multiple.
        /// - parameter rule: `.toNearestOrAwayFromZero` for snap-to-nearest,
        ///                   `.up` / `.down` for directional advance/retreat.
        private func nearestSnap5(raw: CGFloat,
                                   rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Int {
            let maxIndex = Int(parent.range.upperBound - parent.range.lowerBound)
            let s = Int((raw / CGFloat(snapStep)).rounded(rule)) * snapStep
            return min(max(0, s), maxIndex)
        }

        /// Content offset that centres `value` under the indicator.
        private func targetOffset(for value: Double, sv: UIScrollView) -> CGFloat {
            CGFloat(tickIndex(for: value)) * parent.tickSpacing - sv.contentInset.left
        }

        /// Snap the tape to the nearest 5 g mark and commit value + lastIndex.
        private func snapToNearestTick(_ sv: UIScrollView) {
            let raw = rawFractionalIndex(from: sv.contentOffset.x, sv: sv)
            let idx = nearestSnap5(raw: raw)
            let target = CGFloat(idx) * parent.tickSpacing - sv.contentInset.left

            // Commit snap position and value before the animation so the binding
            // is already correct when the animation fires scrollViewDidScroll.
            lastIndex = idx
            let newValue = Double(Int(parent.range.lowerBound) + idx)
            if newValue != parent.value { parent.value = newValue }

            if abs(target - sv.contentOffset.x) > 0.5 {
                drivingProgrammatically = true
                sv.setContentOffset(CGPoint(x: target, y: 0), animated: true)
            }
        }
    }
}

// MARK: · Tick drawing (Core Graphics)

private final class RulerTickView: UIView {
    let range: ClosedRange<Double>
    let tickSpacing: CGFloat
    var ink: UIColor { didSet { setNeedsDisplay() } }

    init(range: ClosedRange<Double>, tickSpacing: CGFloat, ink: UIColor) {
        self.range       = range
        self.tickSpacing = tickSpacing
        self.ink         = ink
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque        = false
        contentMode     = .redraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let count = Int(range.upperBound - range.lowerBound) + 1
        let labelFont  = UIFont.systemFont(ofSize: 9, weight: .semibold)
        let labelColor = ink.withAlphaComponent(0.50)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font:            labelFont,
            .foregroundColor: labelColor,
        ]

        ctx.setLineWidth(1.5)

        // Restrict drawing to the dirty rect for scroll performance.
        // Step by 5 — we only draw ticks at 5 g intervals.
        let step     = 5
        let firstRaw = max(0, Int((rect.minX / tickSpacing) - CGFloat(step)))
        let firstIdx = (firstRaw / step) * step          // round down to step boundary
        let lastIdx  = min(count - 1, Int((rect.maxX / tickSpacing) + CGFloat(step)))
        guard firstIdx <= lastIdx else { return }

        var i = firstIdx
        while i <= lastIdx {
            let v = Int(range.lowerBound) + i
            let x = CGFloat(i) * tickSpacing + tickSpacing / 2

            // Tick hierarchy: labelled at 25 g, tall at 25 g, short at 5 g
            let isLabelled = v % 25 == 0
            let alpha: CGFloat = isLabelled ? 0.75 : 0.30
            let h:     CGFloat = isLabelled ? 20   : 10

            ctx.setStrokeColor(ink.withAlphaComponent(alpha).cgColor)
            ctx.setLineWidth(isLabelled ? 1.5 : 1.0)
            ctx.beginPath()
            ctx.move(to:    CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: h))
            ctx.strokePath()

            if isLabelled {
                let text = "\(v)"
                let size = text.size(withAttributes: labelAttrs)
                text.draw(
                    at: CGPoint(x: x - size.width / 2, y: h + 2),
                    withAttributes: labelAttrs
                )
            }

            i += step
        }
    }
}

// MARK: - Quick-add food data

struct QuickFood: Identifiable {
    let id           = UUID()
    let emoji:        String
    let name:         String
    let p:            Double
    let c:            Double
    let f:            Double
    /// Typical single serving in grams — shown as a hint and used as default weight.
    let typicalGrams: Double
    var kcal: Double { p * 4 + c * 4 + f * 9 }
}

struct QuickCategory: Identifiable {
    let id    = UUID()
    let label: String      // row header
    let color: Color       // accent for the header label
    let foods: [QuickFood]
}

let quickCategories: [QuickCategory] = [

    QuickCategory(label: "Protein", color: Color(hex: "F0A080"), foods: [
        QuickFood(emoji: "🍗", name: "Chicken",    p: 31,  c: 0,  f: 3.5, typicalGrams: 150),
        QuickFood(emoji: "🥩", name: "Beef",       p: 26,  c: 0,  f: 15,  typicalGrams: 150),
        QuickFood(emoji: "🐟", name: "Tuna",       p: 30,  c: 0,  f: 1,   typicalGrams: 85),
        QuickFood(emoji: "🍣", name: "Salmon",     p: 25,  c: 0,  f: 13,  typicalGrams: 120),
        QuickFood(emoji: "🥚", name: "Egg",        p: 13,  c: 1,  f: 11,  typicalGrams: 60),
        QuickFood(emoji: "🍖", name: "Pork",       p: 27,  c: 0,  f: 14,  typicalGrams: 150),
        QuickFood(emoji: "🦃", name: "Turkey",     p: 29,  c: 0,  f: 7,   typicalGrams: 150),
        QuickFood(emoji: "🦐", name: "Shrimp",     p: 24,  c: 0,  f: 1,   typicalGrams: 100),
        QuickFood(emoji: "🥛", name: "Cottage ch", p: 11,  c: 3,  f: 4,   typicalGrams: 100),
    ]),

    QuickCategory(label: "Carbs", color: Color(hex: "FFD080"), foods: [
        QuickFood(emoji: "🍚", name: "Rice",       p: 2.5, c: 28, f: 0.3, typicalGrams: 180),
        QuickFood(emoji: "🍞", name: "Bread",      p: 8,   c: 49, f: 3,   typicalGrams: 40),
        QuickFood(emoji: "🌾", name: "Oats",       p: 13,  c: 66, f: 7,   typicalGrams: 80),
        QuickFood(emoji: "🍝", name: "Pasta",      p: 5,   c: 25, f: 1,   typicalGrams: 200),
        QuickFood(emoji: "🌱", name: "Quinoa",     p: 4,   c: 21, f: 1.9, typicalGrams: 185),
        QuickFood(emoji: "🍠", name: "Sweet pot",  p: 1.6, c: 20, f: 0.1, typicalGrams: 150),
        QuickFood(emoji: "🍠", name: "Potato",     p: 2,   c: 17, f: 0.1, typicalGrams: 150),
        QuickFood(emoji: "🫘", name: "Lentils",    p: 9,   c: 20, f: 0.4, typicalGrams: 200),
        QuickFood(emoji: "🌽", name: "Corn",       p: 3,   c: 19, f: 1.5, typicalGrams: 80),
    ]),

    QuickCategory(label: "Fats", color: Color(hex: "90DBA8"), foods: [
        QuickFood(emoji: "🧈", name: "Butter",     p: 0.5, c: 0,  f: 81,  typicalGrams: 15),
        QuickFood(emoji: "🫒", name: "Olive oil",  p: 0,   c: 0,  f: 100, typicalGrams: 15),
        QuickFood(emoji: "🥑", name: "Avocado",    p: 2,   c: 9,  f: 15,  typicalGrams: 100),
        QuickFood(emoji: "🧀", name: "Cheese",     p: 25,  c: 0,  f: 33,  typicalGrams: 30),
        QuickFood(emoji: "🥜", name: "Peanuts",    p: 26,  c: 16, f: 49,  typicalGrams: 30),
        QuickFood(emoji: "🫙", name: "Peanut b.",  p: 25,  c: 20, f: 50,  typicalGrams: 32),
        QuickFood(emoji: "🌰", name: "Almonds",    p: 21,  c: 22, f: 50,  typicalGrams: 28),
        QuickFood(emoji: "🫙", name: "Cream",      p: 2,   c: 3,  f: 35,  typicalGrams: 30),
        QuickFood(emoji: "🥛", name: "Whole milk", p: 3.4, c: 5,  f: 3.6, typicalGrams: 240),
        QuickFood(emoji: "🍶", name: "Gk yogurt",  p: 9,   c: 4,  f: 0.4, typicalGrams: 150),
    ]),
]

// MARK: - Food chip (pure toggle, no stepper inside)

private struct FoodChip: View {
    let food:       QuickFood
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button { onTap() } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Text(food.emoji)
                        .font(.system(size: 28))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.primary.opacity(0.75)).padding(1))
                            .offset(x: 7, y: -7)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .frame(width: 38, height: 38)

                Text(food.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(Int(food.kcal))kcal")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary.opacity(0.55))
            }
            .frame(width: 70)
            .padding(.vertical, 12)
            .background(isSelected ? Color.primary.opacity(0.11) : Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary.opacity(0.40) : Color.primary.opacity(0.07),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.spring(duration: 0.22, bounce: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selected food row (emoji + name + gram stepper)

private struct SelectedFoodRow: View {
    let food:    QuickFood
    let grams:   Double
    let onStep:  (Double) -> Void   // ±25
    let onRemove: () -> Void

    private let step: Double = 25

    var body: some View {
        HStack(spacing: 10) {
            // Remove button
            Button {
                haptic()
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(food.emoji)
                .font(.system(size: 22))

            Text(food.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.85))
                .lineLimit(1)

            Spacer()

            // Gram stepper
            HStack(spacing: 0) {
                Button {
                    haptic()
                    onStep(-step)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(grams <= step)

                Text("\(Int(grams))g")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(minWidth: 44, alignment: .center)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: grams)

                Button {
                    haptic()
                    onStep(+step)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Quick-add sheet

struct QuickAddSheet: View {
    /// Called once when the user confirms — receives (protein, carbs, fat) to add.
    /// The caller is responsible for baking any active scaler before adding.
    let onAdd: (Double, Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    /// Maps food id → grams. Nothing committed to parent until "Add" is tapped.
    @State private var selected: [UUID: Double] = [:]

    private var allFoods: [QuickFood] { quickCategories.flatMap(\.foods) }
    private var selectedFoods: [QuickFood] {
        // preserve insertion-ish order by iterating allFoods
        allFoods.filter { selected[$0.id] != nil }
    }

    private func contribution(of food: QuickFood) -> (p: Double, c: Double, f: Double) {
        guard let g = selected[food.id] else { return (0, 0, 0) }
        let s = g / 100.0
        return (food.p * s, food.c * s, food.f * s)
    }
    private var pendingP: Double { allFoods.reduce(0) { $0 + contribution(of: $1).p } }
    private var pendingC: Double { allFoods.reduce(0) { $0 + contribution(of: $1).c } }
    private var pendingF: Double { allFoods.reduce(0) { $0 + contribution(of: $1).f } }
    private var pendingKcal: Int { Int(pendingP * 4 + pendingC * 4 + pendingF * 9) }
    private var hasSelection: Bool { !selected.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Text("Quick Add")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                if hasSelection {
                    Button {
                        haptic()
                        withAnimation(.spring(duration: 0.25)) { selected.removeAll() }
                    } label: {
                        Text("Clear all")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: hasSelection)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 14)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(quickCategories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.label.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(category.color)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(category.foods) { food in
                                        FoodChip(
                                            food:       food,
                                            isSelected: selected[food.id] != nil,
                                            onTap: {
                                                haptic()
                                                withAnimation(.spring(duration: 0.25)) {
                                                    if selected[food.id] != nil {
                                                        selected.removeValue(forKey: food.id)
                                                    } else {
                                                        selected[food.id] = 100
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            // ── Selected tray ─────────────────────────────────
            if hasSelection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("IN THIS MEAL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)

                    VStack(spacing: 6) {
                        ForEach(selectedFoods) { food in
                            SelectedFoodRow(
                                food:   food,
                                grams:  selected[food.id] ?? 100,
                                onStep: { delta in
                                    withAnimation(.spring(duration: 0.2)) {
                                        selected[food.id] = max(25, (selected[food.id] ?? 100) + delta)
                                    }
                                },
                                onRemove: {
                                    haptic()
                                    withAnimation(.spring(duration: 0.25)) {
                                        selected.removeValue(forKey: food.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // ── Tally + Add button ────────────────────────────
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    MacroTally(label: "Protein", value: pendingP, color: Color(hex: "F0A080"))
                    Divider().frame(height: 28)
                    MacroTally(label: "Carbs",   value: pendingC, color: Color(hex: "FFD080"))
                    Divider().frame(height: 28)
                    MacroTally(label: "Fat",     value: pendingF, color: Color(hex: "90DBA8"))
                }
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.07), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(hasSelection ? 1 : 0.35)
                .animation(.easeInOut(duration: 0.2), value: hasSelection)

                Button {
                    guard hasSelection else { return }
                    haptic(.medium)
                    onAdd(pendingP, pendingC, pendingF)
                    dismiss()
                } label: {
                    Text(hasSelection
                         ? "Add \(selected.count) \(selected.count == 1 ? "food" : "foods") · \(pendingKcal) kcal"
                         : "Select foods above")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(hasSelection ? .black.opacity(0.85) : Color.primary.opacity(0.25))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(hasSelection ? Color.primary.opacity(0.9) : Color.primary.opacity(0.07))
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.2), value: hasSelection)
                }
                .buttonStyle(.plain)
                .disabled(!hasSelection)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

private struct MacroTally: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(String(format: "%.1f", value) + "g")
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: value)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Action card

private struct ActionCard: View {
    let icon:     String
    let title:    String
    let subtitle: String
    let onTap:    () -> Void

    @Environment(\.themeInk) private var ink

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(ink.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(ink.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.85))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(ink.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(ink.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.13), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Unified Log View
//
// One sheet: manual entry OR scan both inform the same macro block.
// After a scan the main block compacts into a named chip (tap to re-expand).
// Quick-add foods appear as individual inline rows with per-item gram control.

// ── Macro formatting helper ────────────────────────────────────────────────
// Shows 1 decimal place for non-integer values (e.g. 3.5g fat), whole numbers
// for anything that rounds cleanly (e.g. 25g protein).

private func macroStr(_ v: Double) -> String {
    let r = (v * 10).rounded() / 10
    return r.truncatingRemainder(dividingBy: 1) == 0
        ? "\(Int(r))"
        : String(format: "%.1f", r)
}

// ── Food row model ─────────────────────────────────────────────────────────

struct UFoodRow: Identifiable {
    let id       = UUID()
    let emoji:   String
    let name:    String
    let pPer100: Double
    let cPer100: Double
    let fPer100: Double
    var grams:       Double = 100
    var isExpanded:  Bool   = false
    var isUserAdded: Bool   = false

    var protein: Double { pPer100 * grams / 100 }
    var carbs:   Double { cPer100 * grams / 100 }
    var fat:     Double { fPer100 * grams / 100 }
    var kcal:    Double { protein * 4 + carbs * 4 + fat * 9 }
}

// MARK: - Receipt log view

struct ReceiptLogView: View {
    let gradTop:    Color
    let gradBottom: Color
    let onSave:     (FoodEntry) -> Void
    /// When true, panel opens directly on the Scan tab (long-press shortcut).
    var startInScanMode: Bool = false

    @Environment(\.dismiss)     private var dismiss
    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    @State private var items:         [UFoodRow] = []
    @State private var addMode:       RAddMode   = .manual
    @State private var confirmed:     Bool       = false
    @State private var panelExpanded: Bool       = true
    @State private var foodDisplayMode: RFoodDisplayMode = .servings
    @StateObject private var inlineScanner = NutritionScanner()

    // Manual entry state
    @State private var manualProtein: Double = 0
    @State private var manualCarbs:   Double = 0
    @State private var manualFat:     Double = 0
    @State private var manualName:    String = ""
    @State private var catIdx:        Int    = 0

    private var totalP:    Double { items.reduce(0) { $0 + $1.protein } }
    private var totalC:    Double { items.reduce(0) { $0 + $1.carbs   } }
    private var totalF:    Double { items.reduce(0) { $0 + $1.fat     } }
    private var totalKcal: Double { totalP * 4 + totalC * 4 + totalF * 9 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [gradTop, gradBottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────
                HStack {
                    Text("Log meal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.85))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ink.opacity(0.45))
                            .frame(width: 32, height: 32)
                            .background(ink.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // ── Item list ─────────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        if items.isEmpty {
                            Text("Nothing here yet — add something below")
                                .font(.system(size: 14))
                                .foregroundStyle(ink.opacity(0.35))
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 32)
                        }

                        ForEach($items) { $item in
                            RItemRow(item: $item) {
                                withAnimation(.spring(duration: 0.25)) {
                                    items.removeAll { $0.id == item.id }
                                }
                            }
                        }

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

                // ── Add panel ─────────────────────────────────────────
                addPanel
                    .onChange(of: items.count) { old, new in
                        if old == 0 && new == 1 {
                            withAnimation(.spring(duration: 0.4)) { panelExpanded = false }
                        }
                    }
                    .onChange(of: addMode) { _, mode in
                        if mode == .scan && panelExpanded {
                            inlineScanner.start()
                        } else {
                            inlineScanner.stop()
                        }
                    }
                    .onChange(of: panelExpanded) { _, expanded in
                        if addMode == .scan && expanded {
                            inlineScanner.start()
                        } else {
                            inlineScanner.stop()
                        }
                    }
                    .onAppear {
                        // Long-press shortcut from the home button → land on Scan
                        if startInScanMode { addMode = .scan }
                        if addMode == .scan && panelExpanded {
                            inlineScanner.start()
                        }
                    }
                    .onDisappear { inlineScanner.stop() }
                    .onChange(of: inlineScanner.isLocked) { _, locked in
                        guard locked else { return }
                        hapticPulse(times: 3, style: .medium, interval: 0.08)
                        let p     = inlineScanner.protein ?? 0
                        let c     = inlineScanner.carbs   ?? 0
                        let f     = inlineScanner.fat     ?? 0
                        let basis = inlineScanner.basisGrams
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            addScannedItem(p: p, c: c, f: f, basis: basis)
                            inlineScanner.resetForRescan()
                            withAnimation(.spring(duration: 0.4)) { panelExpanded = false }
                        }
                    }

                // ── Footer ────────────────────────────────────────────
                VStack(spacing: 10) {
                    // Glass macro + energy panel
                    HStack(spacing: 0) {
                        VStack(spacing: 1) {
                            Text(totalKcal > 0 ? "\(Int(totalKcal))" : "—")
                                .font(.system(size: 22, weight: .bold).monospacedDigit())
                                .contentTransition(.numericText())
                                .animation(.spring(duration: 0.2), value: totalKcal)
                            Text("kcal")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(totalKcal > 0 ? ink : ink.opacity(0.3))
                        .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(ink.opacity(0.15))
                            .frame(width: 1, height: 34)

                        rMacroTotal(macroStr(totalP) + "g", "P", ink)
                        rMacroTotal(macroStr(totalC) + "g", "C", MacroPalette.carbs(for: scheme))
                        rMacroTotal(macroStr(totalF) + "g", "F", MacroPalette.fat(for: scheme))
                    }
                    .padding(.vertical, 12)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))

                    // Eaten button
                    Button {
                        guard totalKcal > 0 else { return }
                        haptic(.medium)
                        onSave(FoodEntry(protein: totalP, carbs: totalC, fat: totalF))
                        withAnimation { confirmed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                    } label: {
                        Group {
                            if confirmed {
                                Text("✓  logged")
                                    .font(.system(size: 18, weight: .semibold))
                            } else if totalKcal > 0 {
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    Text("Eaten")
                                        .font(.system(size: 16, weight: .semibold)).opacity(0.7)
                                    Text("  \(Int(totalKcal))")
                                        .font(.system(size: 26, weight: .bold).monospacedDigit())
                                    Text(" kcal")
                                        .font(.system(size: 15)).opacity(0.7)
                                }
                            } else {
                                Text("Add something first")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .foregroundStyle(totalKcal > 0 ? Color.black.opacity(0.85) : ink.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(totalKcal > 0 ? .white.opacity(confirmed ? 1.0 : 0.93) : .white.opacity(0.12))
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.2), value: confirmed)
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmed)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: Helpers

    private func addScannedItem(p: Double, c: Double, f: Double, basis: Double) {
        let row = UFoodRow(
            emoji: "📷", name: "Scanned",
            pPer100: p * 100 / max(basis, 1),
            cPer100: c * 100 / max(basis, 1),
            fPer100: f * 100 / max(basis, 1),
            grams: 100, isExpanded: true
        )
        withAnimation(.spring(duration: 0.3)) { items.append(row) }
    }

    /// Tapping a quick food merges into the existing row if one is already
    /// in the meal. This way "tap chicken twice" → one row with 2 servings
    /// (300g) instead of two separate chicken rows. Manual & scanned items
    /// always stay separate (they may have totally different nutrition profiles
    /// even if named the same thing).
    private func addQuickFood(_ food: QuickFood) {
        if let idx = items.firstIndex(where: { $0.emoji == food.emoji && $0.name == food.name }) {
            withAnimation(.spring(duration: 0.3)) {
                items[idx].grams      += food.typicalGrams
                items[idx].isExpanded = true
            }
        } else {
            let row = UFoodRow(emoji: food.emoji, name: food.name,
                               pPer100: food.p, cPer100: food.c, fPer100: food.f,
                               grams: food.typicalGrams, isExpanded: true)
            withAnimation(.spring(duration: 0.3)) { items.append(row) }
        }
    }

    /// Total grams of this food currently in the meal (matched by name + emoji).
    private func totalGramsAdded(for food: QuickFood) -> Double {
        items.filter { $0.name == food.name && $0.emoji == food.emoji }
             .reduce(0) { $0 + $1.grams }
    }

    /// Number of servings (rounded to nearest int) for this food. With merge
    /// + serving-size-per-tap, this is grams ÷ typicalGrams.
    private func servingsAdded(for food: QuickFood) -> Int {
        let g = totalGramsAdded(for: food)
        guard g > 0, food.typicalGrams > 0 else { return 0 }
        return max(1, Int((g / food.typicalGrams).rounded()))
    }

    private func addManualItem() {
        guard manualProtein + manualCarbs + manualFat > 0 else { return }
        let row = UFoodRow(
            emoji: "✏️",
            name:  manualName.trimmingCharacters(in: .whitespaces).isEmpty ? "Manual" : manualName,
            pPer100: manualProtein, cPer100: manualCarbs, fPer100: manualFat,
            grams: 100, isExpanded: true, isUserAdded: true
        )
        withAnimation(.spring(duration: 0.4)) { panelExpanded = false }
        withAnimation(.spring(duration: 0.3)) { items.append(row) }
        manualProtein = 0; manualCarbs = 0; manualFat = 0; manualName = ""
    }

    // MARK: - Add panel

    @ViewBuilder private var addPanel: some View {
        VStack(spacing: 0) {
            // Tab pill row + collapse toggle
            HStack(spacing: 6) {
                ForEach(RAddMode.allCases, id: \.self) { mode in
                    Button {
                        haptic()
                        withAnimation(.spring(duration: 0.2)) {
                            addMode = mode
                            panelExpanded = true
                        }
                    } label: {
                        Text(mode.label)
                            .font(.system(size: 13, weight: addMode == mode ? .semibold : .regular))
                            .foregroundStyle(addMode == mode ? ink : ink.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(addMode == mode ? ink.opacity(0.15) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    haptic()
                    withAnimation(.spring(duration: 0.3)) { panelExpanded.toggle() }
                } label: {
                    Image(systemName: panelExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ink.opacity(0.35))
                        .padding(8)
                        .background(ink.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if panelExpanded {
                Divider().opacity(0.15)
                panelContent
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(ink.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(ink.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder private var panelContent: some View {
        switch addMode {
        case .foods:
            RFoodGrid(
                catIdx:           $catIdx,
                displayMode:      $foodDisplayMode,
                gramsForFood:     totalGramsAdded(for:),
                servingsForFood:  servingsAdded(for:),
                onAdd:            addQuickFood
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        case .manual:
            RManualEntry(protein: $manualProtein, carbs: $manualCarbs,
                         fat: $manualFat, name: $manualName) { addManualItem() }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
        case .scan:
            RInlineScannerView(scanner: inlineScanner)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func rMacroTotal(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: value)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ink.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Receipt add mode

private enum RAddMode: String, Hashable, CaseIterable {
    case manual, scan, foods
    var label: String {
        switch self {
        case .manual: return "Manual"
        case .scan:   return "Scan"
        case .foods:  return "Foods"
        }
    }
}

/// How the foods grid surfaces "amount of this food in the meal" on each chip.
private enum RFoodDisplayMode: String, Hashable, CaseIterable {
    case grams, servings
    var label: String {
        switch self {
        case .grams:    return "g"
        case .servings: return "serving"
        }
    }
}

// MARK: - Receipt item row

private struct RItemRow: View {
    @Binding var item: UFoodRow
    let onDelete: () -> Void

    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            // ── Header row ───────────────────────────────────────
            // Split into two tap targets:
            //  - left/center: tap-to-expand (uses onTapGesture, not Button,
            //    so SwiftUI's Button highlight doesn't swallow taps)
            //  - right:       isolated subtle delete button
            HStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(item.emoji)
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .background(ink.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ink.opacity(0.85))
                        // Tiny macros only visible when collapsed —
                        // the expanded view has its own big panel.
                        if !item.isExpanded {
                            HStack(spacing: 6) {
                                Text("\(Int(item.grams))g")
                                    .foregroundStyle(ink.opacity(0.5))
                                Text("·")
                                    .foregroundStyle(ink.opacity(0.2))
                                Text("\(macroStr(item.protein))P")
                                Text("\(macroStr(item.carbs))C")
                                Text("\(macroStr(item.fat))F")
                            }
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(ink.opacity(0.45))
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.2), value: item.grams)
                            .transition(.opacity)
                        }
                    }

                    Spacer()

                    if !item.isExpanded {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Int(item.kcal))")
                                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                                .foregroundStyle(ink.opacity(0.85))
                                .contentTransition(.numericText())
                                .animation(.spring(duration: 0.2), value: item.grams)
                            Text("kcal")
                                .font(.system(size: 10))
                                .foregroundStyle(ink.opacity(0.4))
                        }
                        .transition(.opacity)
                    }

                    Image(systemName: item.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink.opacity(0.25))
                }
                .padding(.leading, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    haptic()
                    withAnimation(.spring(duration: 0.3)) { item.isExpanded.toggle() }
                }

                // Subtle delete button — small, low-contrast, always present.
                // Tap fires onDelete; parent handles the row-removal animation.
                Button {
                    haptic()
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(ink.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
                .padding(.trailing, 10)
            }

            // ── Expanded gram picker + clear macro breakdown ─────
            if item.isExpanded {
                Rectangle().fill(ink.opacity(0.08)).frame(height: 1)
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        REditMacro(value: Int(item.grams), unit: "g",    color: ink)
                        Rectangle().fill(ink.opacity(0.12)).frame(width: 1, height: 30)
                        REditMacro(value: Int(item.kcal),  unit: "kcal", color: ink)
                        Rectangle().fill(ink.opacity(0.12)).frame(width: 1, height: 30)
                        REditMacro(value: item.protein,    unit: "P",    color: ink)
                        REditMacro(value: item.carbs,      unit: "C",    color: MacroPalette.carbs(for: scheme))
                        REditMacro(value: item.fat,        unit: "F",    color: MacroPalette.fat(for: scheme))
                    }
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ink.opacity(0.06)))

                    GramChipPicker(value: $item.grams, presets: [50, 100, 150, 200, 300])
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(ink.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Inline scanner (live camera preview embedded in the Scan tab)

private struct RInlineScannerView: View {
    @ObservedObject var scanner: NutritionScanner
    @Environment(\.themeInk) private var ink
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 10) {
            // CRITICAL: no clipShape on this hierarchy — AVCaptureVideoPreviewLayer
            // breaks under SwiftUI clip masks. Background shape gives the rounded look.
            GeometryReader { geo in
                ZStack {
                    Color.black

                    CameraPreviewView(session: scanner.session)
                        .frame(width: geo.size.width, height: geo.size.height)

                    ScanBracketsShape()
                        .stroke(
                            .white.opacity(scanner.isLocked ? 0 : 0.35 + scanner.confidence * 0.65),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )
                        .padding(20)
                        .animation(.easeInOut(duration: 0.2), value: scanner.confidence)

                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "AAF0C8").opacity(scanner.isLocked ? 0.95 : 0), lineWidth: 3)
                        .animation(.spring(duration: 0.3), value: scanner.isLocked)

                    VStack {
                        Spacer()
                        Text(scanner.isLocked ? "✓  Got it" : "Aim at the nutrition label")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(.bottom, 12)
                            .animation(.easeInOut(duration: 0.2), value: scanner.isLocked)
                    }
                }
            }
            .frame(height: 200)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.15), lineWidth: 1))

            // Live macro readout — fills as the scanner detects values
            HStack(spacing: 0) {
                RScanMacro(label: "P", value: scanner.protein, color: ink)
                RScanMacro(label: "C", value: scanner.carbs,   color: MacroPalette.carbs(for: scheme))
                RScanMacro(label: "F", value: scanner.fat,     color: MacroPalette.fat(for: scheme))
            }
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(ink.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.1), lineWidth: 1))
        }
    }
}

private struct RScanMacro: View {
    let label: String
    let value: Double?
    let color: Color
    @Environment(\.themeInk) private var ink

    var body: some View {
        VStack(spacing: 2) {
            Text(value.map { String(format: "%.1fg", $0) } ?? "—")
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(value != nil ? color : ink.opacity(0.3))
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.25), value: value)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ink.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Macro readout used inside an expanded item row. Generic over Double/Int values.
private struct REditMacro: View {
    private let display: String
    private let unit: String
    private let color: Color

    init(value: Double, unit: String, color: Color) {
        self.display = String(format: "%.1f", value)
        self.unit    = unit
        self.color   = color
    }
    init(value: Int, unit: String, color: Color) {
        self.display = "\(value)"
        self.unit    = unit
        self.color   = color
    }

    @Environment(\.themeInk) private var ink

    var body: some View {
        VStack(spacing: 2) {
            Text(display)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: display)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ink.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Receipt food grid (swipeable categories)

private struct RFoodGrid: View {
    @Binding var catIdx: Int
    @Binding var displayMode: RFoodDisplayMode
    /// Returns total grams of this food currently in the meal.
    let gramsForFood:    (QuickFood) -> Double
    /// Returns serving count of this food currently in the meal.
    let servingsForFood: (QuickFood) -> Int
    let onAdd: (QuickFood) -> Void

    @Environment(\.themeInk) private var ink
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 10) {
            // Category pills + display-mode toggle on the right
            HStack(spacing: 6) {
                ForEach(quickCategories.indices, id: \.self) { i in
                    Button {
                        haptic()
                        withAnimation(.spring(duration: 0.3)) { catIdx = i }
                    } label: {
                        Text(quickCategories[i].label)
                            .font(.system(size: 12, weight: catIdx == i ? .semibold : .regular))
                            .foregroundStyle(catIdx == i ? ink : ink.opacity(0.45))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(catIdx == i ? ink.opacity(0.15) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                displayModeToggle
            }

            // Swipeable, scrollable pages
            TabView(selection: $catIdx) {
                ForEach(quickCategories.indices, id: \.self) { i in
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(quickCategories[i].foods) { food in
                                let grams    = gramsForFood(food)
                                let servings = servingsForFood(food)
                                ZStack(alignment: .topTrailing) {
                                    Button { haptic(); onAdd(food) } label: {
                                        VStack(spacing: 4) {
                                            Text(food.emoji).font(.system(size: 22))
                                            Text(food.name)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(ink.opacity(0.7))
                                                .lineLimit(1)
                                            Text("\(Int(food.typicalGrams))g")
                                                .font(.system(size: 9).monospacedDigit())
                                                .foregroundStyle(ink.opacity(0.35))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(ink.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)

                                    // Notification-style badge — content depends on mode
                                    if grams > 0 {
                                        Text(displayMode == .servings
                                             ? "×\(servings)"
                                             : "\(Int(grams))g")
                                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.red))
                                            .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1.5))
                                            .shadow(color: .red.opacity(0.4), radius: 3, y: 1)
                                            .contentTransition(.numericText())
                                            .offset(x: 6, y: -6)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .animation(.spring(duration: 0.3), value: grams)
                                .animation(.spring(duration: 0.3), value: displayMode)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 8)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 360)
        }
    }

    /// Compact g/serving toggle that lives next to the category pills.
    private var displayModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(RFoodDisplayMode.allCases, id: \.self) { mode in
                Button {
                    haptic()
                    withAnimation(.spring(duration: 0.25)) { displayMode = mode }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 11, weight: displayMode == mode ? .semibold : .regular))
                        .foregroundStyle(displayMode == mode ? ink : ink.opacity(0.45))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(displayMode == mode ? ink.opacity(0.15) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(ink.opacity(0.06)))
    }
}

// MARK: - Receipt manual entry

private struct RManualEntry: View {
    @Binding var protein: Double
    @Binding var carbs:   Double
    @Binding var fat:     Double
    @Binding var name:    String
    let onAdd: () -> Void

    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    private var hasValues: Bool { protein + carbs + fat > 0 }

    var body: some View {
        VStack(spacing: 0) {
            UMacroStepper(label: "Protein", value: $protein, color: ink,
                          pills: [5, 10, 25])
            Divider().background(ink.opacity(0.08))
            UMacroStepper(label: "Carbs", value: $carbs,
                          color: MacroPalette.carbs(for: scheme), pills: [10, 25, 50])
            Divider().background(ink.opacity(0.08))
            UMacroStepper(label: "Fat", value: $fat,
                          color: MacroPalette.fat(for: scheme), pills: [5, 10, 20])

            Divider().background(ink.opacity(0.08))
            HStack(spacing: 10) {
                TextField("Name (optional)", text: $name)
                    .font(.system(size: 14))
                    .foregroundStyle(ink.opacity(0.8))
                    .tint(ink)
                Button {
                    haptic()
                    onAdd()
                } label: {
                    Text("Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hasValues ? ink : ink.opacity(0.3))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(hasValues ? ink.opacity(0.15) : ink.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!hasValues)
            }
            .padding(.vertical, 12)
        }
    }
}

// ── Main view ──────────────────────────────────────────────────────────────

struct UnifiedLogView: View {
    @Environment(\.dismiss)     private var dismiss
    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    let gradTop:    Color
    let gradBottom: Color
    let onSave:     (FoodEntry) -> Void

    // Main block
    @State private var entryName:        String    = ""
    @State private var protein:          Double    = 0
    @State private var carbs:            Double    = 0
    @State private var fat:              Double    = 0
    @State private var useScaling:       Bool      = false
    @State private var scaleMode:        ScaleMode = .weight
    @State private var basisGrams:       Double    = 100
    @State private var amount:           Double    = 100
    @State private var servingMultiplier: Double   = 1.0
    @State private var mainExpanded:     Bool      = true
    @State private var isScanned:        Bool      = false

    // Food items
    @State private var foodItems:        [UFoodRow] = []

    // Inline food picker
    @State private var showInlineAdd:    Bool = false
    @State private var inlineCatIdx:     Int  = 0

    // Scanner
    @State private var showScanner:      Bool = false
    @State private var confirmed:        Bool = false

    // ── Scale helpers ───────────────────────────────────────────────────────

    private var scale: Double {
        guard useScaling && basisGrams > 0 else { return 1 }
        switch scaleMode {
        case .weight:   return amount / basisGrams
        case .servings: return servingMultiplier
        }
    }

    private var scaledP: Double { protein * scale }
    private var scaledC: Double { carbs   * scale }
    private var scaledF: Double { fat     * scale }

    private var totalP:    Double { scaledP + foodItems.reduce(0) { $0 + $1.protein } }
    private var totalC:    Double { scaledC + foodItems.reduce(0) { $0 + $1.carbs   } }
    private var totalF:    Double { scaledF + foodItems.reduce(0) { $0 + $1.fat     } }
    private var totalKcal: Double { totalP * 4 + totalC * 4 + totalF * 9 }

    // ── Body ────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            LinearGradient(colors: [gradTop, gradBottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    uHeaderRow
                    uMainBlock
                    if !foodItems.isEmpty {
                        uFoodItemsSection
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3)) {
                                    mainExpanded = false
                                }
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
                            }
                    }
                    uAddFoodSection
                    Spacer(minLength: 8)
                    uFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 44)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .fullScreenCover(isPresented: $showScanner) {
            FoodScannerView { p, c, f, basis in
                protein    = p
                carbs      = c
                fat        = f
                // Scanned values are always per 100 g — start there, user adjusts
                basisGrams = basis > 0 ? basis : 100
                amount     = 100
                withAnimation(.spring(duration: 0.4)) {
                    useScaling   = true
                    isScanned    = true
                    mainExpanded = true   // stay open so user can see & adjust
                }
            }
        }
    }

    // MARK: Header

    private var uHeaderRow: some View {
        Text("Log meal")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ink.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Add main block as a named user food item

    private func addMainBlockAsItem() {
        guard !entryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let s = scale
        let row = UFoodRow(
            emoji:       "✏️",
            name:        entryName,
            pPer100:     protein * s,
            cPer100:     carbs   * s,
            fPer100:     fat     * s,
            isUserAdded: true
        )
        withAnimation(.spring(duration: 0.3)) {
            foodItems.insert(row, at: 0)   // top of list
        }
        // Reset main block for next entry
        entryName        = ""
        protein          = 0
        carbs            = 0
        fat              = 0
        useScaling       = false
        amount           = 100
        servingMultiplier = 1.0
        basisGrams       = 100
    }

    // MARK: Main block — switches between expanded editor and compact chip

    @ViewBuilder
    private var uMainBlock: some View {
        if mainExpanded {
            UExpandedBlock(
                entryName:         $entryName,
                protein:           $protein,
                carbs:             $carbs,
                fat:               $fat,
                useScaling:        $useScaling,
                scaleMode:         $scaleMode,
                basisGrams:        $basisGrams,
                amount:            $amount,
                servingMultiplier: $servingMultiplier,
                isScanned:         isScanned,
                onScan:            { haptic(); showScanner = true },
                onAddAsItem:       { addMainBlockAsItem() },
                onCollapse:        {
                    withAnimation(.spring(duration: 0.3)) { mainExpanded = false }
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else {
            UCompactChip(
                protein:   scaledP,
                carbs:     scaledC,
                fat:       scaledF,
                name:      entryName,
                isScanned: isScanned
            ) {
                haptic()
                withAnimation(.spring(duration: 0.3)) { mainExpanded = true }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        }
    }

    // MARK: Food items — "User" section on top, quick-add below

    private var uFoodItemsSection: some View {
        VStack(spacing: 8) {
            let userIDs = foodItems.filter {  $0.isUserAdded }.map { $0.id }
            let quickIDs = foodItems.filter { !$0.isUserAdded }.map { $0.id }

            // ── User-named items ──────────────────────────────────
            if !userIDs.isEmpty {
                HStack {
                    Text("User")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(ink.opacity(0.38))
                    Spacer()
                }
                .padding(.horizontal, 2)

                ForEach(userIDs, id: \.self) { id in
                    if let idx = foodItems.firstIndex(where: { $0.id == id }) {
                        let i = idx
                        SwipeToDelete {
                            haptic()
                            withAnimation(.spring(duration: 0.25)) { foodItems.remove(at: i); return }
                        } content: {
                            UFoodItemRow(item: $foodItems[i]) {
                                withAnimation(.spring(duration: 0.25)) { foodItems.remove(at: i); return }
                            }
                        }
                    }
                }
            }

            // ── Quick-add items ───────────────────────────────────
            ForEach(quickIDs, id: \.self) { id in
                if let idx = foodItems.firstIndex(where: { $0.id == id }) {
                    let i = idx
                    SwipeToDelete {
                        haptic()
                        withAnimation(.spring(duration: 0.25)) { foodItems.remove(at: i); return }
                    } content: {
                        UFoodItemRow(item: $foodItems[i]) {
                            withAnimation(.spring(duration: 0.25)) { foodItems.remove(at: i); return }
                        }
                    }
                }
            }
        }
    }

    // MARK: Inline add food

    private var uAddFoodSection: some View {
        VStack(spacing: 10) {
            // Card-style toggle button — same visual weight as a food chip
            Button {
                haptic()
                withAnimation(.spring(duration: 0.3)) {
                    showInlineAdd.toggle()
                    // Collapse the main entry block so the food grid has room
                    if showInlineAdd { mainExpanded = false }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: showInlineAdd ? "xmark" : "fork.knife")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(ink.opacity(0.65))
                        .frame(width: 34, height: 34)
                        .background(ink.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    Text(showInlineAdd ? "Done" : "Add food to this meal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ink.opacity(0.7))
                    Spacer()
                    Image(systemName: showInlineAdd ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink.opacity(0.28))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(ink.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                    showInlineAdd ? ink.opacity(0.22) : ink.opacity(0.13), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)

            if showInlineAdd {
                UInlineFoodPicker(catIdx: $inlineCatIdx) { food in
                    let row = UFoodRow(
                        emoji:   food.emoji,
                        name:    food.name,
                        pPer100: food.p,
                        cPer100: food.c,
                        fPer100: food.f,
                        grams:   food.typicalGrams   // start at realistic serving size
                    )
                    withAnimation(.spring(duration: 0.3)) {
                        foodItems.append(row)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Footer — total + Eaten

    private var uFooter: some View {
        VStack(spacing: 14) {
            if totalKcal > 0 {
                HStack(spacing: 0) {
                    UTotalMacro(value: totalP, label: "P", color: ink)
                    UTotalMacro(value: totalC, label: "C", color: MacroPalette.carbs(for: scheme))
                    UTotalMacro(value: totalF, label: "F", color: MacroPalette.fat(for: scheme))
                }
                .padding(.vertical, 10)
                .background(ink.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.1), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Button {
                guard totalKcal > 0 else { return }
                haptic(.medium)
                onSave(FoodEntry(protein: totalP, carbs: totalC, fat: totalF))
                withAnimation { confirmed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
            } label: {
                Group {
                    if confirmed {
                        Text("✓  logged")
                            .font(.system(size: 18, weight: .semibold))
                    } else if totalKcal > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("Eaten")
                                .font(.system(size: 16, weight: .semibold))
                                .opacity(0.7)
                            Text("  \(Int(totalKcal))")
                                .font(.system(size: 26, weight: .bold).monospacedDigit())
                            Text(" kcal")
                                .font(.system(size: 15, weight: .regular))
                                .opacity(0.7)
                        }
                    } else {
                        Text("Eaten")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundStyle(totalKcal > 0 ? gradTop : ink.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(totalKcal > 0 ? ink.opacity(confirmed ? 1.0 : 0.9) : ink.opacity(0.12))
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.2), value: confirmed)
                .animation(.easeInOut(duration: 0.2), value: totalKcal > 0)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Expanded macro editor block

private struct UExpandedBlock: View {
    @Binding var entryName:        String
    @Binding var protein:          Double
    @Binding var carbs:            Double
    @Binding var fat:              Double
    @Binding var useScaling:       Bool
    @Binding var scaleMode:        ScaleMode
    @Binding var basisGrams:       Double
    @Binding var amount:           Double
    @Binding var servingMultiplier: Double
    let isScanned:    Bool
    let onScan:       () -> Void
    let onAddAsItem:  () -> Void
    let onCollapse:   () -> Void

    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    @State private var showNameInput: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Macro rows (pill style) ─────────────────────────────
            UMacroStepper(label: "Protein", value: $protein,
                          color: ink,
                          pills: [5, 10, 25])
            divider
            UMacroStepper(label: "Carbs",   value: $carbs,
                          color: MacroPalette.carbs(for: scheme),
                          pills: [10, 25, 50])
            divider
            UMacroStepper(label: "Fat",     value: $fat,
                          color: MacroPalette.fat(for: scheme),
                          pills: [5, 10, 20])

            // ── Scale section ───────────────────────────────────────
            if useScaling {
                divider
                VStack(spacing: 10) {
                    // Mode toggle
                    Picker("", selection: $scaleMode) {
                        ForEach(ScaleMode.allCases, id: \.rawValue) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if scaleMode == .weight {
                        // Prominent weight number
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(Int(amount))")
                                .font(.system(size: 36, weight: .medium).monospacedDigit())
                                .foregroundStyle(ink)
                                .contentTransition(.numericText())
                                .animation(.spring(duration: 0.2), value: amount)
                            Text("g")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(ink.opacity(0.5))
                            Spacer()
                            let s = basisGrams > 0 ? amount / basisGrams : 1
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("×\(String(format: "%.2f", s))")
                                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                                    .foregroundStyle(ink.opacity(0.5))
                                Text("per \(Int(basisGrams))g basis")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ink.opacity(0.32))
                            }
                        }
                        GramChipPicker(value: $amount, presets: [100, 150, 200, 300, 500])
                    } else {
                        HStack {
                            Text("Servings")
                                .font(.system(size: 14))
                                .foregroundStyle(ink.opacity(0.7))
                            Spacer()
                            Button {
                                haptic()
                                servingMultiplier = max(0.25, servingMultiplier - 0.25)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(ink.opacity(0.4))
                            }.buttonStyle(.plain)

                            Text(String(format: "%.2f", servingMultiplier))
                                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                                .frame(minWidth: 60, alignment: .center)
                                .foregroundStyle(ink)
                                .contentTransition(.numericText())
                                .animation(.spring(duration: 0.3), value: servingMultiplier)

                            Button {
                                haptic()
                                servingMultiplier = min(10, servingMultiplier + 0.25)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(ink.opacity(0.9))
                            }.buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 12)
            }

            // ── Inline name field (shown when showNameInput) ────────
            if showNameInput {
                divider
                HStack(spacing: 8) {
                    TextField("Name this item…", text: $entryName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ink.opacity(0.85))
                        .tint(ink)
                        .submitLabel(.done)

                    Button {
                        haptic()
                        onAddAsItem()
                        showNameInput = false
                    } label: {
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(ink.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .disabled(entryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 10)
            }

            // ── Bottom action row ───────────────────────────────────
            divider
            HStack(spacing: 10) {
                // Scan
                Button { onScan() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 13))
                        Text("Scan")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(ink.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ink.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Scale toggle
                Button {
                    haptic()
                    withAnimation(.spring(duration: 0.3)) { useScaling.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: useScaling ? "scalemass.fill" : "scalemass")
                            .font(.system(size: 13))
                        Text(useScaling ? "Scaling on" : "Scale")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(useScaling ? ink : ink.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(useScaling ? ink.opacity(0.16) : ink.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Name toggle
                Button {
                    haptic()
                    withAnimation(.spring(duration: 0.25)) { showNameInput.toggle() }
                    if !showNameInput { entryName = "" }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showNameInput ? "character.cursor.ibeam" : "tag")
                            .font(.system(size: 13))
                        Text(showNameInput ? "Cancel" : "Name")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(showNameInput ? ink : ink.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(showNameInput ? ink.opacity(0.16) : ink.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(ink.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(ink.opacity(0.13), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var divider: some View {
        Rectangle()
            .fill(ink.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, 10)
    }
}

// MARK: - Compact scanned chip

private struct UCompactChip: View {
    let protein:   Double
    let carbs:     Double
    let fat:       Double
    let name:      String
    let isScanned: Bool
    let onExpand:  () -> Void

    @Environment(\.themeInk) private var ink

    private var kcal: Double { protein * 4 + carbs * 4 + fat * 9 }
    private var displayName: String {
        name.isEmpty ? (isScanned ? "Scanned" : "Manual") : name
    }

    var body: some View {
        Button { onExpand() } label: {
            HStack(spacing: 12) {
                Image(systemName: isScanned ? "camera.fill" : "pencil")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(ink.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(ink.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.85))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text("\(macroStr(protein))P")
                        Text("\(macroStr(carbs))C")
                        Text("\(macroStr(fat))F")
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(ink.opacity(0.5))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(kcal))")
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .foregroundStyle(ink.opacity(0.85))
                    Text("kcal")
                        .font(.system(size: 10))
                        .foregroundStyle(ink.opacity(0.4))
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink.opacity(0.28))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(ink.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.13), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ruler needle (downward-pointing triangle, fixed centre marker)

private struct RulerNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))   // tip pointing down
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Gram chip picker (replaces ruler)

private struct GramChipPicker: View {
    @Binding var value: Double
    let presets: [Double]

    @Environment(\.themeInk) private var ink

    var body: some View {
        VStack(spacing: 10) {
            // ── Preset chips ──────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(presets, id: \.self) { preset in
                        let selected = abs(value - preset) < 1
                        Button {
                            haptic()
                            withAnimation(.spring(duration: 0.2)) { value = preset }
                        } label: {
                            Text("\(Int(preset))g")
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? ink : ink.opacity(0.65))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(selected ? ink.opacity(0.18) : ink.opacity(0.08))
                                .overlay(
                                    Capsule().stroke(selected ? ink.opacity(0.28) : Color.clear, lineWidth: 1.5)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            // ── Ruler for fine-tuning ─────────────────────────────
            RulerScrollView(value: $value, range: 25...1000, ink: ink)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(alignment: .top) {
                    // Fixed center needle — shows exactly where the value sits
                    VStack(spacing: 0) {
                        RulerNeedle()
                            .fill(ink)
                            .frame(width: 10, height: 6)
                        Rectangle()
                            .fill(ink.opacity(0.7))
                            .frame(width: 2, height: 18)
                    }
                    .allowsHitTesting(false)
                }
        }
    }
}

// MARK: - Macro stepper row (pill style — big value left, quick steps middle, minus right)

private struct UMacroStepper: View {
    let label: String
    @Binding var value: Double
    let color: Color
    let pills: [Double]   // quick-add increments shown as capsule buttons

    @Environment(\.themeInk) private var ink

    /// Tracks the press state for the minus button so we can:
    /// 1. Show a subtle scale-down while pressed (visual feedback)
    /// 2. Suppress the trailing tap action when a long-press already fired
    @State private var minusIsPressing = false
    @State private var minusLongPressFired = false

    var body: some View {
        HStack(spacing: 12) {
            // Big value display
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink.opacity(0.45))
                Text("\(Int(value))g")
                    .font(.system(size: 26, weight: .medium).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.25), value: value)
            }
            .frame(width: 78, alignment: .leading)

            // Quick-step pills
            HStack(spacing: 7) {
                ForEach(pills, id: \.self) { amt in
                    Button {
                        haptic()
                        value = max(0, value + amt)
                    } label: {
                        Text("+\(Int(amt))")
                            .font(.system(size: 13, weight: .medium))
                            .fixedSize()
                            .foregroundStyle(ink.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(ink.opacity(0.1))
                            .overlay(Capsule().stroke(ink.opacity(0.14), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)

            // Subtract smallest pill — long-press resets to zero.
            // Uses the same canonical Apple pattern as the home log button:
            // standalone Image + onLongPressGesture(perform:onPressingChanged:)
            // + simultaneousGesture(TapGesture). Button doesn't work here because
            // it consumes the press immediately and the long-press timer never starts.
            Image(systemName: "minus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ink.opacity(0.45))
                .frame(width: 32, height: 32)
                .background(ink.opacity(0.08))
                .clipShape(Circle())
                .scaleEffect(minusIsPressing ? 0.9 : 1)
                .animation(.spring(duration: 0.2), value: minusIsPressing)
                .contentShape(Circle())
                .onLongPressGesture(
                    minimumDuration: 0.4,
                    perform: {
                        minusLongPressFired = true
                        haptic(.medium)
                        withAnimation(.spring(duration: 0.3)) { value = 0 }
                    },
                    onPressingChanged: { pressing in
                        minusIsPressing = pressing
                        if !pressing {
                            // Reset the guard a tick after release so the
                            // simultaneous TapGesture can read it correctly.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                minusLongPressFired = false
                            }
                        }
                    }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            guard !minusLongPressFired else { return }
                            haptic()
                            value = max(0, value - pills[0])
                        }
                )
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Food item row
//
// Compact chip (same visual language as UCompactChip).
// Tap to expand → weight ruler for gram adjustment, same UX as main block.

private struct UFoodItemRow: View {
    @Binding var item: UFoodRow
    let onRemove: () -> Void

    @Environment(\.themeInk) private var ink

    var body: some View {
        VStack(spacing: 0) {
            // ── Compact header — same visual language as UCompactChip ─
            Button {
                haptic()
                withAnimation(.spring(duration: 0.3)) { item.isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text(item.emoji)
                        .font(.system(size: 18))
                        .frame(width: 34, height: 34)
                        .background(ink.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ink.opacity(0.85))
                        HStack(spacing: 7) {
                            Text("\(macroStr(item.protein))P")
                            Text("\(macroStr(item.carbs))C")
                            Text("\(macroStr(item.fat))F")
                            Text("·")
                                .foregroundStyle(ink.opacity(0.2))
                            Text("\(Int(item.grams))g")
                                .foregroundStyle(ink.opacity(0.55))
                        }
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(ink.opacity(0.45))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.2), value: item.grams)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(item.kcal))")
                            .font(.system(size: 18, weight: .semibold).monospacedDigit())
                            .foregroundStyle(ink.opacity(0.85))
                            .animation(.spring(duration: 0.2), value: item.grams)
                        Text("kcal")
                            .font(.system(size: 10))
                            .foregroundStyle(ink.opacity(0.4))
                    }

                    Image(systemName: item.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink.opacity(0.28))
                        .padding(.leading, 2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Expanded: weight ruler + remove ──────────────────────
            if item.isExpanded {
                Rectangle()
                    .fill(ink.opacity(0.08))
                    .frame(height: 1)

                VStack(spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(Int(item.grams))")
                            .font(.system(size: 32, weight: .medium).monospacedDigit())
                            .foregroundStyle(ink)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.2), value: item.grams)
                        Text("g")
                            .font(.system(size: 16))
                            .foregroundStyle(ink.opacity(0.5))
                        Spacer()
                        Text("\(Int(item.kcal)) kcal")
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(ink.opacity(0.35))
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.2), value: item.grams)
                    }
                    GramChipPicker(value: $item.grams, presets: [50, 100, 150, 200, 300])
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(ink.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.13), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Inline food picker

private struct UInlineFoodPicker: View {
    @Binding var catIdx: Int
    let onAdd: (QuickFood) -> Void

    @Environment(\.themeInk) private var ink

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category tabs
            HStack(spacing: 8) {
                ForEach(quickCategories.indices, id: \.self) { i in
                    let cat = quickCategories[i]
                    Button {
                        haptic()
                        withAnimation(.spring(duration: 0.2)) { catIdx = i }
                    } label: {
                        Text(cat.label)
                            .font(.system(size: 12, weight: catIdx == i ? .semibold : .regular))
                            .foregroundStyle(catIdx == i ? ink : ink.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(catIdx == i ? ink.opacity(0.15) : ink.opacity(0.07))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Food grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(quickCategories[catIdx].foods) { food in
                    Button { haptic(); onAdd(food) } label: {
                        VStack(spacing: 4) {
                            Text(food.emoji)
                                .font(.system(size: 22))
                            Text(food.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ink.opacity(0.7))
                                .lineLimit(1)
                            Text("\(Int(food.typicalGrams))g")
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(ink.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ink.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(ink.opacity(0.11), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(ink.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.09), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Total macro chip

private struct UTotalMacro: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(macroStr(value))g")
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: value)
            Text(label)
                .font(.system(size: 10))
                .tracking(0.5)
                .foregroundStyle(color.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

#Preview {
    LogFoodView(gradTop: Color(hex: "E8A878"), gradBottom: Color(hex: "F0C070")) { _ in }
}
