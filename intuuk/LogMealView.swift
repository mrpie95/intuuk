import SwiftUI

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

// MARK: - Shared utilities

/// Macro formatting helper. Shows 1 decimal place for non-integer values
/// (e.g. 3.5g fat), whole numbers for anything that rounds cleanly
/// (e.g. 25g protein).
private func macroStr(_ v: Double) -> String {
    let r = (v * 10).rounded() / 10
    return r.truncatingRemainder(dividingBy: 1) == 0
        ? "\(Int(r))"
        : String(format: "%.1f", r)
}

/// One row in the meal-being-logged list. Stores per-100g macros + a current
/// gram amount; the actual P/C/F/kcal are derived live so the UI stays in sync
/// when the user adjusts the amount.
struct LogFoodItem: Identifiable {
    let id       = UUID()
    let emoji:   String
    let name:    String
    let pPer100: Double
    let cPer100: Double
    let fPer100: Double
    var grams:      Double = 100
    var isExpanded: Bool   = false

    var protein: Double { pPer100 * grams / 100 }
    var carbs:   Double { cPer100 * grams / 100 }
    var fat:     Double { fPer100 * grams / 100 }
    var kcal:    Double { protein * 4 + carbs * 4 + fat * 9 }
}

// MARK: - Log meal view

struct LogMealView: View {
    let gradTop:    Color
    let gradBottom: Color
    let onSave:     (FoodEntry) -> Void
    /// When true, panel opens directly on the Scan tab (long-press shortcut).
    var startInScanMode: Bool = false

    @Environment(\.dismiss)     private var dismiss
    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    @State private var items:         [LogFoodItem] = []
    @State private var addMode:       LogAddMode   = .manual
    @State private var confirmed:     Bool       = false
    @State private var panelExpanded: Bool       = true
    @State private var foodDisplayMode: LogFoodDisplayMode = .servings
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
                            LogItemRow(item: $item) {
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
        let row = LogFoodItem(
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
            let row = LogFoodItem(emoji: food.emoji, name: food.name,
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
        let row = LogFoodItem(
            emoji: "✏️",
            name:  manualName.trimmingCharacters(in: .whitespaces).isEmpty ? "Manual" : manualName,
            pPer100: manualProtein, cPer100: manualCarbs, fPer100: manualFat,
            grams: 100, isExpanded: true
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
                ForEach(LogAddMode.allCases, id: \.self) { mode in
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
            LogFoodGrid(
                catIdx:           $catIdx,
                displayMode:      $foodDisplayMode,
                gramsForFood:     totalGramsAdded(for:),
                servingsForFood:  servingsAdded(for:),
                onAdd:            addQuickFood
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        case .manual:
            LogManualEntry(protein: $manualProtein, carbs: $manualCarbs,
                         fat: $manualFat, name: $manualName) { addManualItem() }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
        case .scan:
            LogScannerView(scanner: inlineScanner)
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

private enum LogAddMode: String, Hashable, CaseIterable {
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
private enum LogFoodDisplayMode: String, Hashable, CaseIterable {
    case grams, servings
    var label: String {
        switch self {
        case .grams:    return "g"
        case .servings: return "serving"
        }
    }
}

// MARK: - Receipt item row

private struct LogItemRow: View {
    @Binding var item: LogFoodItem
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
                        EditMacroChip(value: Int(item.grams), unit: "g",    color: ink)
                        Rectangle().fill(ink.opacity(0.12)).frame(width: 1, height: 30)
                        EditMacroChip(value: Int(item.kcal),  unit: "kcal", color: ink)
                        Rectangle().fill(ink.opacity(0.12)).frame(width: 1, height: 30)
                        EditMacroChip(value: item.protein,    unit: "P",    color: ink)
                        EditMacroChip(value: item.carbs,      unit: "C",    color: MacroPalette.carbs(for: scheme))
                        EditMacroChip(value: item.fat,        unit: "F",    color: MacroPalette.fat(for: scheme))
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

private struct LogScannerView: View {
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
                ScanMacroChip(label: "P", value: scanner.protein, color: ink)
                ScanMacroChip(label: "C", value: scanner.carbs,   color: MacroPalette.carbs(for: scheme))
                ScanMacroChip(label: "F", value: scanner.fat,     color: MacroPalette.fat(for: scheme))
            }
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(ink.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.opacity(0.1), lineWidth: 1))
        }
    }
}

private struct ScanMacroChip: View {
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
private struct EditMacroChip: View {
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

private struct LogFoodGrid: View {
    @Binding var catIdx: Int
    @Binding var displayMode: LogFoodDisplayMode
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
            ForEach(LogFoodDisplayMode.allCases, id: \.self) { mode in
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

private struct LogManualEntry: View {
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
            MacroStepper(label: "Protein", value: $protein, color: ink,
                          pills: [5, 10, 25])
            Divider().background(ink.opacity(0.08))
            MacroStepper(label: "Carbs", value: $carbs,
                          color: MacroPalette.carbs(for: scheme), pills: [10, 25, 50])
            Divider().background(ink.opacity(0.08))
            MacroStepper(label: "Fat", value: $fat,
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

private struct MacroStepper: View {
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

