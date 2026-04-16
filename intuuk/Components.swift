import SwiftUI
import Charts

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

// MARK: - Theme presets

struct GradStop { let at: Double; let a: Color; let b: Color }

/// User-controlled appearance override. `.auto` follows the system; `.light`/`.dark`
/// pin it regardless of system preference.
enum ThemeAppearance: String, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:  return "Automatic"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }

    /// Applied via `.preferredColorScheme(...)` — nil = follow system.
    var colorScheme: ColorScheme? {
        switch self {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

enum GradientTheme: String, CaseIterable, Identifiable {
    // Elemental quartet
    case fire   = "fire"
    case ocean  = "ocean"          // water
    case nature = "nature"         // earth
    case air    = "air"            // new

    // Aesthetic trio
    case aurora     = "aurora"
    case candy      = "candy"      // blossom
    case monochrome = "monochrome" // dusk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fire:       return "Fire"
        case .ocean:      return "Water"
        case .nature:     return "Earth"
        case .air:        return "Air"
        case .aurora:     return "Aurora"
        case .candy:      return "Blossom"
        case .monochrome: return "Dusk"
        }
    }

    // ── Appearance-aware stops ────────────────────────────────
    func stops(for scheme: ColorScheme) -> [GradStop] {
        scheme == .light ? lightStops : darkStops
    }

    /// The original, dark-mode-leaning stops (cool → bright → deep saturated warm).
    private var darkStops: [GradStop] {
        switch self {

        case .fire:
            return [
                .init(at: 0,    a: .init(hex: "3A70C0"), b: .init(hex: "5840A8")),
                .init(at: 0.15, a: .init(hex: "4A88C8"), b: .init(hex: "6858B0")),
                .init(at: 0.35, a: .init(hex: "E8A878"), b: .init(hex: "F0C070")),
                .init(at: 0.55, a: .init(hex: "F09050"), b: .init(hex: "F4B040")),
                .init(at: 0.75, a: .init(hex: "E87030"), b: .init(hex: "D85020")),
                .init(at: 0.90, a: .init(hex: "CC4820"), b: .init(hex: "B83018")),
                .init(at: 1.00, a: .init(hex: "B83018"), b: .init(hex: "8C1E10")),
                .init(at: 1.15, a: .init(hex: "7A1408"), b: .init(hex: "500C04")),
            ]

        case .ocean:
            return [
                .init(at: 0,    a: .init(hex: "1A3050"), b: .init(hex: "203860")),
                .init(at: 0.15, a: .init(hex: "204870"), b: .init(hex: "286080")),
                .init(at: 0.35, a: .init(hex: "30A0A8"), b: .init(hex: "38B098")),
                .init(at: 0.55, a: .init(hex: "50B890"), b: .init(hex: "60C080")),
                .init(at: 0.75, a: .init(hex: "E88060"), b: .init(hex: "D86848")),
                .init(at: 0.90, a: .init(hex: "D06040"), b: .init(hex: "C04828")),
                .init(at: 1.00, a: .init(hex: "B84828"), b: .init(hex: "983018")),
                .init(at: 1.15, a: .init(hex: "803018"), b: .init(hex: "601808")),
            ]

        case .nature:
            return [
                .init(at: 0,    a: .init(hex: "286040"), b: .init(hex: "307848")),
                .init(at: 0.15, a: .init(hex: "387848"), b: .init(hex: "488840")),
                .init(at: 0.35, a: .init(hex: "B8B858"), b: .init(hex: "C8A840")),
                .init(at: 0.55, a: .init(hex: "C8982C"), b: .init(hex: "D08820")),
                .init(at: 0.75, a: .init(hex: "C87020"), b: .init(hex: "B85818")),
                .init(at: 0.90, a: .init(hex: "A85010"), b: .init(hex: "903808")),
                .init(at: 1.00, a: .init(hex: "883008"), b: .init(hex: "702004")),
                .init(at: 1.15, a: .init(hex: "5C1804"), b: .init(hex: "401002")),
            ]

        case .air:
            // Dark stormy slate → steel blue → dusty violet
            return [
                .init(at: 0,    a: .init(hex: "2C3A50"), b: .init(hex: "344258")),
                .init(at: 0.15, a: .init(hex: "3A4C64"), b: .init(hex: "425470")),
                .init(at: 0.35, a: .init(hex: "6080A0"), b: .init(hex: "7088A8")),
                .init(at: 0.55, a: .init(hex: "7890B0"), b: .init(hex: "8898B8")),
                .init(at: 0.75, a: .init(hex: "8878A0"), b: .init(hex: "9878A0")),
                .init(at: 0.90, a: .init(hex: "785878"), b: .init(hex: "684858")),
                .init(at: 1.00, a: .init(hex: "604050"), b: .init(hex: "483038")),
                .init(at: 1.15, a: .init(hex: "382028"), b: .init(hex: "201018")),
            ]

        case .aurora:
            return [
                .init(at: 0,    a: .init(hex: "5870B8"), b: .init(hex: "7848A8")),
                .init(at: 0.15, a: .init(hex: "6880C0"), b: .init(hex: "8860B0")),
                .init(at: 0.35, a: .init(hex: "F0C8A8"), b: .init(hex: "ECC498")),
                .init(at: 0.55, a: .init(hex: "ECA888"), b: .init(hex: "E89878")),
                .init(at: 0.75, a: .init(hex: "E48898"), b: .init(hex: "D87080")),
                .init(at: 0.90, a: .init(hex: "D07080"), b: .init(hex: "C05870")),
                .init(at: 1.00, a: .init(hex: "C05870"), b: .init(hex: "A04058")),
                .init(at: 1.15, a: .init(hex: "903050"), b: .init(hex: "702040")),
            ]

        case .candy:
            return [
                .init(at: 0,    a: .init(hex: "3868B8"), b: .init(hex: "6038A8")),
                .init(at: 0.15, a: .init(hex: "4878C0"), b: .init(hex: "7050B0")),
                .init(at: 0.35, a: .init(hex: "90D0B8"), b: .init(hex: "A0C8A8")),
                .init(at: 0.55, a: .init(hex: "F0A8B8"), b: .init(hex: "E890C0")),
                .init(at: 0.75, a: .init(hex: "E880A0"), b: .init(hex: "D86890")),
                .init(at: 0.90, a: .init(hex: "D06080"), b: .init(hex: "B84870")),
                .init(at: 1.00, a: .init(hex: "C04870"), b: .init(hex: "A02858")),
                .init(at: 1.15, a: .init(hex: "902048"), b: .init(hex: "701030")),
            ]

        case .monochrome:
            return [
                .init(at: 0,    a: .init(hex: "5858A0"), b: .init(hex: "484890")),
                .init(at: 0.15, a: .init(hex: "6860A8"), b: .init(hex: "587098")),
                .init(at: 0.35, a: .init(hex: "9080C0"), b: .init(hex: "8068B0")),
                .init(at: 0.55, a: .init(hex: "7058A8"), b: .init(hex: "604898")),
                .init(at: 0.75, a: .init(hex: "503878"), b: .init(hex: "402868")),
                .init(at: 0.90, a: .init(hex: "3C2860"), b: .init(hex: "2C1850")),
                .init(at: 1.00, a: .init(hex: "2C1850"), b: .init(hex: "1C0840")),
                .init(at: 1.15, a: .init(hex: "180630"), b: .init(hex: "100420")),
            ]
        }
    }

    /// Light-mode stops: all colours kept in the 70-90 % luminance band so the
    /// themed dark ink reads cleanly at every ratio.
    private var lightStops: [GradStop] {
        switch self {

        case .fire:
            // Pale sky → peach → soft coral
            return [
                .init(at: 0,    a: .init(hex: "B8CEE8"), b: .init(hex: "C0D4F0")),
                .init(at: 0.15, a: .init(hex: "C0D0EC"), b: .init(hex: "C8D8F0")),
                .init(at: 0.35, a: .init(hex: "FAD8B8"), b: .init(hex: "F8D0A8")),
                .init(at: 0.55, a: .init(hex: "F8C098"), b: .init(hex: "F8B888")),
                .init(at: 0.75, a: .init(hex: "F0A880"), b: .init(hex: "E89878")),
                .init(at: 0.90, a: .init(hex: "E89078"), b: .init(hex: "DC8068")),
                .init(at: 1.00, a: .init(hex: "D88070"), b: .init(hex: "C87060")),
                .init(at: 1.15, a: .init(hex: "C06858"), b: .init(hex: "A85040")),
            ]

        case .ocean:
            // Pale slate → seafoam → soft coral
            return [
                .init(at: 0,    a: .init(hex: "C8D8E0"), b: .init(hex: "C8D8E8")),
                .init(at: 0.15, a: .init(hex: "C8DCE8"), b: .init(hex: "D0DCE8")),
                .init(at: 0.35, a: .init(hex: "C0E4DC"), b: .init(hex: "C8E4D8")),
                .init(at: 0.55, a: .init(hex: "D8E4CC"), b: .init(hex: "E0DCC0")),
                .init(at: 0.75, a: .init(hex: "F0CCB0"), b: .init(hex: "ECC0A0")),
                .init(at: 0.90, a: .init(hex: "E8B8A0"), b: .init(hex: "E0A890")),
                .init(at: 1.00, a: .init(hex: "D8A898"), b: .init(hex: "C8987C")),
                .init(at: 1.15, a: .init(hex: "C09080"), b: .init(hex: "A87868")),
            ]

        case .nature:
            // Pale mint → butter cream → soft amber
            return [
                .init(at: 0,    a: .init(hex: "C8D8C0"), b: .init(hex: "CCDCC4")),
                .init(at: 0.15, a: .init(hex: "D0DCC8"), b: .init(hex: "D8DCBC")),
                .init(at: 0.35, a: .init(hex: "E8E4B0"), b: .init(hex: "ECDCA0")),
                .init(at: 0.55, a: .init(hex: "ECD098"), b: .init(hex: "ECC888")),
                .init(at: 0.75, a: .init(hex: "ECB888"), b: .init(hex: "E4A478")),
                .init(at: 0.90, a: .init(hex: "DC9870"), b: .init(hex: "D08C60")),
                .init(at: 1.00, a: .init(hex: "C88050"), b: .init(hex: "B87040")),
                .init(at: 1.15, a: .init(hex: "A86840"), b: .init(hex: "885030")),
            ]

        case .air:
            // Cloud → sky → pale azure
            return [
                .init(at: 0,    a: .init(hex: "E4E8EC"), b: .init(hex: "DCE0E8")),
                .init(at: 0.15, a: .init(hex: "DCE4EC"), b: .init(hex: "D8E0E8")),
                .init(at: 0.35, a: .init(hex: "CCDCEC"), b: .init(hex: "C4D8E8")),
                .init(at: 0.55, a: .init(hex: "BCD0E8"), b: .init(hex: "B0C8E4")),
                .init(at: 0.75, a: .init(hex: "A8BCD8"), b: .init(hex: "98B0D0")),
                .init(at: 0.90, a: .init(hex: "98A8C4"), b: .init(hex: "8898B4")),
                .init(at: 1.00, a: .init(hex: "7C8CA8"), b: .init(hex: "6C7C98")),
                .init(at: 1.15, a: .init(hex: "5C6C88"), b: .init(hex: "4C5C78")),
            ]

        case .aurora:
            // Lavender mist → cream → blush
            return [
                .init(at: 0,    a: .init(hex: "D8D8F0"), b: .init(hex: "E0D8F0")),
                .init(at: 0.15, a: .init(hex: "DCDCF0"), b: .init(hex: "E4DCF0")),
                .init(at: 0.35, a: .init(hex: "F8E4D0"), b: .init(hex: "F8E0C8")),
                .init(at: 0.55, a: .init(hex: "F4D0BC"), b: .init(hex: "F0C8B0")),
                .init(at: 0.75, a: .init(hex: "ECC0C8"), b: .init(hex: "E8B4BC")),
                .init(at: 0.90, a: .init(hex: "E8B0BC"), b: .init(hex: "E0A0B0")),
                .init(at: 1.00, a: .init(hex: "D8A0B0"), b: .init(hex: "C89098")),
                .init(at: 1.15, a: .init(hex: "C09098"), b: .init(hex: "A87880")),
            ]

        case .candy:
            // Baby blue → pale mint → cotton-candy pink
            return [
                .init(at: 0,    a: .init(hex: "C8D8F0"), b: .init(hex: "D0D0E8")),
                .init(at: 0.15, a: .init(hex: "D0D8F0"), b: .init(hex: "D8D4E8")),
                .init(at: 0.35, a: .init(hex: "CCE8D8"), b: .init(hex: "D4E4D0")),
                .init(at: 0.55, a: .init(hex: "F0CCD8"), b: .init(hex: "ECBCD0")),
                .init(at: 0.75, a: .init(hex: "ECB8C8"), b: .init(hex: "E4A8C0")),
                .init(at: 0.90, a: .init(hex: "DCA8BC"), b: .init(hex: "D098B0")),
                .init(at: 1.00, a: .init(hex: "C898AC"), b: .init(hex: "B88098")),
                .init(at: 1.15, a: .init(hex: "B07888"), b: .init(hex: "986070")),
            ]

        case .monochrome:
            // Silver-lavender → soft lilac → dusty mauve
            return [
                .init(at: 0,    a: .init(hex: "D8D8E8"), b: .init(hex: "D4D0E4")),
                .init(at: 0.15, a: .init(hex: "DCD4E8"), b: .init(hex: "D8D0E4")),
                .init(at: 0.35, a: .init(hex: "DCCCE8"), b: .init(hex: "D4C0E0")),
                .init(at: 0.55, a: .init(hex: "D4B8DC"), b: .init(hex: "C8ACD0")),
                .init(at: 0.75, a: .init(hex: "BCA0C8"), b: .init(hex: "AC90BC")),
                .init(at: 0.90, a: .init(hex: "AC90BC"), b: .init(hex: "9C80AC")),
                .init(at: 1.00, a: .init(hex: "9C80AC"), b: .init(hex: "88709C")),
                .init(at: 1.15, a: .init(hex: "887090"), b: .init(hex: "705880")),
            ]
        }
    }

    // ── Per-theme ink colour for light mode ───────────────────
    // White is used in dark mode regardless of theme.
    private var lightInk: Color {
        switch self {
        case .fire:       return .init(hex: "4A1808")   // deep espresso-brick
        case .ocean:      return .init(hex: "0E2838")   // deep teal
        case .nature:     return .init(hex: "1E3A14")   // deep moss
        case .air:        return .init(hex: "1C2838")   // deep slate
        case .aurora:     return .init(hex: "3C1A26")   // deep wine
        case .candy:      return .init(hex: "3E0E24")   // deep magenta
        case .monochrome: return .init(hex: "2A0E3A")   // deep plum
        }
    }

    func ink(for scheme: ColorScheme) -> Color {
        scheme == .light ? lightInk : .white
    }

    /// Three representative colors (mid-row gradient) for the settings swatch.
    func previewColors(for scheme: ColorScheme) -> [Color] {
        let s = stops(for: scheme)
        return [
            lerpColor(s[0].a, s[0].b, t: 0.5),
            lerpColor(s[3].a, s[3].b, t: 0.5),
            lerpColor(s[6].a, s[6].b, t: 0.5),
        ]
    }

    /// Backwards-compat for any callers that haven't been updated.
    var previewColors: [Color] { previewColors(for: .dark) }
}

func gradientColors(for ratio: Double,
                    theme: GradientTheme = .fire,
                    scheme: ColorScheme = .dark) -> (Color, Color) {
    let stops = theme.stops(for: scheme)
    let r = min(ratio, 1.15)
    var lo = stops.first!, hi = stops.last!
    for i in 0 ..< stops.count - 1 {
        if r >= stops[i].at && r <= stops[i + 1].at { lo = stops[i]; hi = stops[i + 1]; break }
    }
    let t = (r - lo.at) / max(hi.at - lo.at, 0.001)
    return (lerpColor(lo.a, hi.a, t: t), lerpColor(lo.b, hi.b, t: t))
}

func lerpColor(_ c1: Color, _ c2: Color, t: Double) -> Color {
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
    UIColor(c1).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    UIColor(c2).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    return Color(red: r1 + (r2-r1)*t, green: g1 + (g2-g1)*t, blue: b1 + (b2-b1)*t)
}

// MARK: - Haptics

func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

/// Fires a series of impact pulses spaced by `interval` seconds.
/// Good for "captured / locked / success" cues that benefit from being
/// distinguishable from a single tap. Reuses one generator + .prepare()
/// so the haptic engine warms up before the first pulse.
func hapticPulse(times: Int = 3,
                 style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
                 interval: TimeInterval = 0.08) {
    let gen = UIImpactFeedbackGenerator(style: style)
    gen.prepare()
    for i in 0..<times {
        DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
            gen.impactOccurred()
        }
    }
}

// MARK: - Macro palette (scheme-aware)
//
// Protein uses the themed ink so it blends with the general text colour.
// Carbs (warm gold) and Fat (green) get light/dark variants because the same
// hue can't cover both a dark navy background and a pastel peach one.

enum MacroPalette {
    static func carbs(for scheme: ColorScheme) -> Color {
        scheme == .light ? .init(hex: "AC6810") : .init(hex: "FFD7A0")
    }
    static func fat(for scheme: ColorScheme) -> Color {
        scheme == .light ? .init(hex: "2E8A4C") : .init(hex: "AAF0C8")
    }
}

// MARK: - Theme-aware ink colour (passed via environment)

private struct ThemeInkKey: EnvironmentKey {
    static let defaultValue: Color = .white
}
extension EnvironmentValues {
    /// The themed ink colour for the current theme × color scheme. Use
    /// `ink.opacity(...)` for secondary/tertiary text instead of hard-coded whites.
    var themeInk: Color {
        get { self[ThemeInkKey.self] }
        set { self[ThemeInkKey.self] = newValue }
    }
}

// MARK: - Animated mesh background

struct AnimatedMeshBg: View {
    let ratio: Double
    let theme: GradientTheme
    let scheme: ColorScheme

    init(ratio: Double, theme: GradientTheme = .fire, scheme: ColorScheme = .dark) {
        self.ratio  = ratio
        self.theme  = theme
        self.scheme = scheme
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate * 0.08)
            MeshGradient(
                width: 3, height: 3,
                points: meshPoints(t: t),
                colors: meshColors(ratio: ratio, t: t)
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.5), value: ratio)
        .animation(.easeInOut(duration: 0.8), value: theme.rawValue)
        .animation(.easeInOut(duration: 0.8), value: scheme)
    }

    private func meshPoints(t: Float) -> [SIMD2<Float>] {
        [
            [0, 0], [0.5, 0], [1, 0],
            [0,   0.45 + 0.10 * sin(t * 0.9)],
            [0.5  + 0.14 * sin(t * 1.1), 0.5 + 0.12 * cos(t * 0.8)],
            [1,   0.45 + 0.10 * cos(t * 1.2)],
            [0, 1],
            [0.5 + 0.12 * cos(t * 0.7), 1],
            [1, 1],
        ]
    }

    private func meshColors(ratio: Double, t: Float) -> [Color] {
        let lo  = gradientColors(for: max(0,    ratio - 0.18), theme: theme, scheme: scheme)
        let mid = gradientColors(for:           ratio,         theme: theme, scheme: scheme)
        let hi  = gradientColors(for: min(1.15, ratio + 0.18), theme: theme, scheme: scheme)

        let s = Double(sin(t) * 0.5 + 0.5)
        let c = Double(cos(t * 1.3) * 0.5 + 0.5)

        return [
            lerpColor(lo.0,  mid.0, t: 0.4),
            lerpColor(mid.0, hi.0,  t: 0.3 + 0.2 * s),
            lerpColor(mid.1, hi.1,  t: 0.5),
            lerpColor(lo.0,  lo.1,  t: 0.5 + 0.2 * c),
            lerpColor(mid.0, mid.1, t: 0.5 + 0.3 * s),
            lerpColor(hi.0,  hi.1,  t: 0.4 + 0.2 * c),
            lerpColor(lo.1,  mid.1, t: 0.5),
            lerpColor(mid.1, hi.0,  t: 0.3 + 0.2 * c),
            lerpColor(hi.1,  mid.0, t: 0.4 + 0.2 * s),
        ]
    }
}

// MARK: - BurndownCard

enum ChartMode: CaseIterable, Equatable {
    case bars, calories, smallMacro, gauge

    var next: ChartMode {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
    var label: String {
        switch self {
        case .bars:       return "today"
        case .calories:   return "calories"
        case .smallMacro: return "macro detail"
        case .gauge:      return "balance"
        }
    }
}

struct BurndownPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
    var series: String = ""
}

struct StackedPoint: Identifiable {
    let id = UUID()
    let time: Date
    let yLow:  Double
    let yHigh: Double
    let macro: String
}

struct BurndownCard: View {
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let entries: [FoodEntry]
    let calorieGoal: Double
    let proteinGoal: Double
    let carbsGoal: Double
    let fatGoal: Double

    @State private var mode: ChartMode = .bars
    @State private var macroShowPct = false
    @Environment(\.themeInk) private var ink

    private var balance: Double {
        entries.reduce(0) { $0 + $1.calories } - calorieGoal
    }

    private var chartEnd: Date {
        let start    = Calendar.current.startOfDay(for: .now)
        let sixHrsIn = Calendar.current.date(byAdding: .hour, value: 6, to: start)!
        let latest   = entries.map { $0.timestamp }.max() ?? .now
        let withBuf  = Calendar.current.date(byAdding: .hour, value: 1, to: max(.now, latest))!
        return max(sixHrsIn, withBuf)
    }
    private var dayStart: Date { Calendar.current.startOfDay(for: .now) }

    // ── Calorie data (can go negative for surplus) ────────────
    private var calorieData: [BurndownPoint] {
        var pts = [BurndownPoint(time: dayStart, value: calorieGoal)]
        var running = calorieGoal
        for e in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            running -= e.calories
            pts.append(BurndownPoint(time: e.timestamp, value: running))
        }
        pts.append(BurndownPoint(time: chartEnd, value: running))
        return pts
    }

    // Split calorie series at the zero crossing for two-zone colouring
    private var calAbove: [BurndownPoint] {
        splitCalorieData().above
    }
    private var calBelow: [BurndownPoint] {
        splitCalorieData().below
    }
    private func splitCalorieData() -> (above: [BurndownPoint], below: [BurndownPoint]) {
        var above: [BurndownPoint] = []
        var below: [BurndownPoint] = []
        let data = calorieData
        for i in 0..<data.count {
            let curr = data[i]
            if curr.value >= 0 { above.append(curr) } else { below.append(curr) }
            if i + 1 < data.count {
                let next = data[i + 1]
                if (curr.value >= 0) != (next.value >= 0) {
                    // Interpolate zero-crossing point
                    let t = abs(curr.value) / (abs(curr.value) + abs(next.value))
                    let crossTime = curr.time.addingTimeInterval(
                        next.time.timeIntervalSince(curr.time) * t)
                    let cross = BurndownPoint(time: crossTime, value: 0)
                    above.append(cross)
                    below.append(cross)
                }
            }
        }
        return (above, below)
    }

    private var calYMin: Double {
        let lowestPoint = calorieData.map { $0.value }.min() ?? 0
        return min(-calorieGoal * 0.15, lowestPoint - 50)
    }

    // ── Cumulative macro series ───────────────────────────────
    private func cumulativeSeries(_ keyPath: KeyPath<FoodEntry, Double>, series: String) -> [BurndownPoint] {
        var pts = [BurndownPoint(time: dayStart, value: 0, series: series)]
        var running = 0.0
        for e in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            running += e[keyPath: keyPath]
            pts.append(BurndownPoint(time: e.timestamp, value: running, series: series))
        }
        pts.append(BurndownPoint(time: chartEnd, value: running, series: series))
        return pts
    }

    // ── Stacked area data (A) ─────────────────────────────────
    private var stackedData: [StackedPoint] {
        var pts: [StackedPoint] = []
        var runP = 0.0, runC = 0.0, runF = 0.0
        let times: [(Date, Double, Double, Double)] = {
            var result = [(dayStart, 0.0, 0.0, 0.0)]
            for e in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
                runP += e.protein; runC += e.carbs; runF += e.fat
                result.append((e.timestamp, runP, runC, runF))
            }
            result.append((chartEnd, runP, runC, runF))
            return result
        }()
        for (t, p, c, f) in times {
            pts.append(StackedPoint(time: t, yLow: 0,     yHigh: p,         macro: "Protein"))
            pts.append(StackedPoint(time: t, yLow: p,     yHigh: p + c,     macro: "Carbs"))
            pts.append(StackedPoint(time: t, yLow: p + c, yHigh: p + c + f, macro: "Fat"))
        }
        return pts
    }
    private var stackYMax: Double {
        let last = stackedData.filter { $0.macro == "Fat" }.map { $0.yHigh }.max() ?? 0
        return max(proteinGoal + carbsGoal + fatGoal, last) * 1.1
    }

    // ── Normalised % series (D) ───────────────────────────────
    private func normalisedSeries(_ kp: KeyPath<FoodEntry, Double>, goal: Double, series: String) -> [BurndownPoint] {
        cumulativeSeries(kp, series: series).map {
            BurndownPoint(time: $0.time, value: goal > 0 ? $0.value / goal * 100 : 0, series: series)
        }
    }

    // MARK: - Extracted chart views (keeps body type-check fast)

    @ViewBuilder private var barsView: some View {
        MacroBar(label: "Protein", left: max(0, proteinGoal - totalProtein), goal: proteinGoal,
                 barColor: .white.opacity(0.85))
        MacroBar(label: "Carbs",   left: max(0, carbsGoal - totalCarbs),     goal: carbsGoal,
                 barColor: Color(hex: "FFD7A0").opacity(0.85))
        MacroBar(label: "Fat",     left: max(0, fatGoal - totalFat),         goal: fatGoal,
                 barColor: Color(hex: "AAF0C8").opacity(0.82))
    }

    @ViewBuilder private var caloriesView: some View {
        Chart {
            ForEach(calAbove) { pt in
                AreaMark(x: .value("T", pt.time), y: .value("kcal", pt.value))
                    .foregroundStyle(LinearGradient(
                        colors: [.white.opacity(0.20), .white.opacity(0.03)],
                        startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            // `series:` tells Charts to treat above/below as two distinct lines —
            // without it, Charts bridges the end of the white line to the start of
            // the orange line with a faint diagonal artifact.
            ForEach(calAbove) { pt in
                LineMark(x: .value("T", pt.time),
                         y: .value("kcal", pt.value),
                         series: .value("Zone", "above"))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            ForEach(calBelow) { pt in
                AreaMark(x: .value("T", pt.time), y: .value("kcal", pt.value))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "FF7030").opacity(0.04), Color(hex: "FF4010").opacity(0.26)],
                        startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            ForEach(calBelow) { pt in
                LineMark(x: .value("T", pt.time),
                         y: .value("kcal", pt.value),
                         series: .value("Zone", "below"))
                    .foregroundStyle(Color(hex: "FF7040").opacity(0.90))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            ForEach(calorieData.dropFirst().dropLast()) { pt in
                PointMark(x: .value("T", pt.time), y: .value("kcal", pt.value))
                    .foregroundStyle(pt.value >= 0 ? AnyShapeStyle(.white) : AnyShapeStyle(Color(hex: "FF7040")))
                    .symbolSize(38)
            }
            RuleMark(y: .value("Goal", 0))
                .foregroundStyle(.white.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("goal").font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55)).padding(.trailing, 4)
                }
        }
        .chartXScale(domain: dayStart...chartEnd)
        .chartYScale(domain: calYMin...(calorieGoal + 100))
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
            AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel() } }
        .chartYAxis(.hidden)
        .frame(height: 180)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var stackedMacroView: some View {
        let pColor = Color.white.opacity(0.75)
        let cColor = Color(hex: "FFD7A0").opacity(0.75)
        let fColor = Color(hex: "AAF0C8").opacity(0.75)
        Chart {
            ForEach(stackedData) { pt in
                AreaMark(x: .value("T", pt.time),
                         yStart: .value("g", pt.yLow),
                         yEnd:   .value("g", pt.yHigh))
                    .foregroundStyle(pt.macro == "Protein" ? pColor : pt.macro == "Carbs" ? cColor : fColor)
                    .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("Goal", proteinGoal + carbsGoal + fatGoal))
                .foregroundStyle(.white.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("goal").font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5)).padding(.trailing, 4)
                }
        }
        .chartXScale(domain: dayStart...chartEnd)
        .chartYScale(domain: 0...stackYMax)
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
            AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel() } }
        .chartYAxis(.hidden)
        .frame(height: 180)
        .environment(\.colorScheme, .dark)

        HStack(spacing: 14) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(pColor).frame(width: 12, height: 8)
                Text("Protein").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(cColor).frame(width: 12, height: 8)
                Text("Carbs").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(fColor).frame(width: 12, height: 8)
                Text("Fat").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder private var smallMacroView: some View {
        VStack(spacing: 16) {
            MiniMacroChart(label: "Protein", data: cumulativeSeries(\.protein, series: "Protein"),
                           goal: proteinGoal, color: .white.opacity(0.9), xDomain: dayStart...chartEnd,
                           showPct: macroShowPct)
            MiniMacroChart(label: "Carbs", data: cumulativeSeries(\.carbs, series: "Carbs"),
                           goal: carbsGoal, color: Color(hex: "FFD7A0"), xDomain: dayStart...chartEnd,
                           showPct: macroShowPct)
            MiniMacroChart(label: "Fat", data: cumulativeSeries(\.fat, series: "Fat"),
                           goal: fatGoal, color: Color(hex: "AAF0C8"), xDomain: dayStart...chartEnd,
                           showPct: macroShowPct)
        }
    }

    @ViewBuilder private var normPctView: some View {
        let normP = normalisedSeries(\.protein, goal: proteinGoal, series: "Protein")
        let normC = normalisedSeries(\.carbs,   goal: carbsGoal,   series: "Carbs")
        let normF = normalisedSeries(\.fat,     goal: fatGoal,     series: "Fat")
        let yMax  = max(115, (normP + normC + normF).map { $0.value }.max().map { $0 * 1.1 } ?? 115)

        Chart {
            ForEach(normP) { pt in
                LineMark(x: .value("T", pt.time), y: .value("%", pt.value))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            ForEach(normP) { pt in
                AreaMark(x: .value("T", pt.time), y: .value("%", pt.value))
                    .foregroundStyle(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.01)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            ForEach(normC) { pt in
                LineMark(x: .value("T", pt.time), y: .value("%", pt.value))
                    .foregroundStyle(Color(hex: "FFD7A0").opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            ForEach(normC) { pt in
                AreaMark(x: .value("T", pt.time), y: .value("%", pt.value))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "FFD7A0").opacity(0.10), Color(hex: "FFD7A0").opacity(0.01)],
                        startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            ForEach(normF) { pt in
                LineMark(x: .value("T", pt.time), y: .value("%", pt.value))
                    .foregroundStyle(Color(hex: "AAF0C8").opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            ForEach(normF) { pt in
                AreaMark(x: .value("T", pt.time), y: .value("%", pt.value))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "AAF0C8").opacity(0.10), Color(hex: "AAF0C8").opacity(0.01)],
                        startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("100%", 100))
                .foregroundStyle(.white.opacity(0.40))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("goal").font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55)).padding(.trailing, 4)
                }
        }
        .chartXScale(domain: dayStart...chartEnd)
        .chartYScale(domain: 0...yMax)
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
            AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel() } }
        .chartYAxis(.hidden)
        .frame(height: 180)
        .environment(\.colorScheme, .dark)

        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Capsule().fill(Color.white.opacity(0.9)).frame(width: 16, height: 3)
                Text("Protein").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 5) {
                Capsule().fill(Color(hex: "FFD7A0")).frame(width: 16, height: 3)
                Text("Carbs").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 5) {
                Capsule().fill(Color(hex: "AAF0C8")).frame(width: 16, height: 3)
                Text("Fat").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                mode = mode.next
                macroShowPct = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(mode == .smallMacro
                         ? (macroShowPct ? "macro % · hold for g" : "macro detail · hold for %")
                         : mode.label + " · tap to cycle")
                        .font(.system(size: 11))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(ink.opacity(0.60))
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(ChartMode.allCases, id: \.label) { m in
                            Circle()
                                .fill(ink.opacity(m == mode ? 0.9 : 0.30))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                switch mode {
                case .bars:
                    barsView
                case .calories:
                    caloriesView
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                case .smallMacro:
                    smallMacroView
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                haptic()
                                withAnimation(.spring(duration: 0.3)) { macroShowPct.toggle() }
                            }
                        )
                case .gauge:
                    BalanceGaugeView(balance: balance, calorieGoal: calorieGoal)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(ink.opacity(0.11))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink.opacity(0.18), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(GlassButton())
    }
}

// MARK: - Balance gauge (power-meter style)
//
// A proper speedometer-style gauge with:
//   • Three clearly-coloured zones (cool blue = deficit, green = on-target, warm = surplus)
//   • Fixed visual proportions (35 / 30 / 35 %) so the "sweet spot" is always the same size
//   • A real needle line pivoting from a centre dot
//   • Number + subtitle sit above the pivot and draw on top of the needle
//
// The balance → arc mapping uses tanh compression so ±150 kcal lands comfortably
// in the green zone and ±goal pushes the needle near the ends regardless of goal size.

private struct BalanceGaugeView: View {
    let balance:     Double
    let calorieGoal: Double

    @Environment(\.themeInk)    private var ink
    @Environment(\.colorScheme) private var scheme

    private let trackWidth: CGFloat = 18

    // ── Fixed visual zone proportions ───────────────────────
    private let deficitEnd:   Double = 0.35
    private let surplusStart: Double = 0.65

    // ── Zone colours — scheme-aware so they read on either bg ─
    private var deficitCol: Color {
        scheme == .light ? Color(hex: "2078B8") : Color(hex: "6FB8E8")
    }
    private var optimalCol: Color {
        scheme == .light ? Color(hex: "1E9050") : Color(hex: "7FEB9F")
    }
    private var surplusCol: Color {
        scheme == .light ? Color(hex: "D05820") : Color(hex: "FF8F60")
    }

    // Balance → 0…1 fraction along the arc.
    // k = goal gives ±150 → frac ≈ 0.45–0.55 (centre of green zone),
    //                  ±goal → frac ≈ 0.05 / 0.95 (near arc ends).
    private var needleFrac: Double {
        let k = max(calorieGoal, 300)
        return (tanh(balance / k * 1.5) + 1) * 0.5
    }

    private func arcPath(from f0: Double, to f1: Double, r: CGFloat, c: CGPoint) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r,
                 startAngle: .init(radians: .pi * (1 + f0)),
                 endAngle:   .init(radians: .pi * (1 + f1)),
                 clockwise:  true)
        return p
    }

    private struct Geo {
        let cx: CGFloat, cy: CGFloat, r: CGFloat, tw: CGFloat
        var c: CGPoint { CGPoint(x: cx, y: cy) }
    }

    private var shadowAlpha: Double { scheme == .dark ? 0.30 : 0.15 }

    private var zoneColour: Color {
        if balance < -150 { return deficitCol }
        if balance >  150 { return surplusCol }
        return optimalCol
    }

    private var subtitle: String {
        if balance < -150 { return "kcal remaining" }
        if balance >  150 { return "kcal over goal" }
        return "on target"
    }

    var body: some View {
        GeometryReader { proxy in
            let g = Geo(
                cx: proxy.size.width / 2,
                cy: proxy.size.height - 26,
                r:  min(proxy.size.width / 2 - trackWidth - 6, proxy.size.height - 26 - 10),
                tw: trackWidth
            )
            ZStack {
                gaugeArcs(g: g)
                gaugeCaps(g: g)
                gaugeBoundaryTicks(g: g)
                gaugeNeedle(g: g)
                gaugeReadout(g: g)
                gaugeEndLabels(g: g)
            }
        }
        .frame(height: 195)
    }

    @ViewBuilder
    private func gaugeArcs(g: Geo) -> some View {
        let butt  = StrokeStyle(lineWidth: g.tw, lineCap: .butt)
        let round = StrokeStyle(lineWidth: g.tw, lineCap: .round)
        // Background track
        arcPath(from: 0, to: 1, r: g.r, c: g.c)
            .stroke(ink.opacity(0.10), style: round)
        // Deficit
        arcPath(from: 0, to: deficitEnd, r: g.r, c: g.c)
            .stroke(deficitCol.opacity(0.75), style: butt)
        // Optimal (full brightness)
        arcPath(from: deficitEnd, to: surplusStart, r: g.r, c: g.c)
            .stroke(optimalCol, style: butt)
        // Surplus
        arcPath(from: surplusStart, to: 1, r: g.r, c: g.c)
            .stroke(surplusCol.opacity(0.75), style: butt)
    }

    @ViewBuilder
    private func gaugeCaps(g: Geo) -> some View {
        Circle().fill(deficitCol.opacity(0.75)).frame(width: g.tw, height: g.tw)
            .position(x: g.cx - g.r, y: g.cy)
        Circle().fill(surplusCol.opacity(0.75)).frame(width: g.tw, height: g.tw)
            .position(x: g.cx + g.r, y: g.cy)
    }

    @ViewBuilder
    private func gaugeBoundaryTicks(g: Geo) -> some View {
        ForEach([deficitEnd, surplusStart], id: \.self) { f in
            let a  = CGFloat.pi * (1 + CGFloat(f))
            let r0 = g.r - g.tw / 2 - 2
            let r1 = g.r + g.tw / 2 + 2
            Path { p in
                p.move(to: CGPoint(x: g.cx + r0 * cos(a), y: g.cy + r0 * sin(a)))
                p.addLine(to: CGPoint(x: g.cx + r1 * cos(a), y: g.cy + r1 * sin(a)))
            }
            .stroke(ink.opacity(0.28), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func gaugeNeedle(g: Geo) -> some View {
        let na     = CGFloat.pi + CGFloat(needleFrac) * CGFloat.pi
        let innerR = g.r * 0.30
        let outerR = g.r - g.tw * 0.5 - 2
        let start  = CGPoint(x: g.cx + innerR * cos(na), y: g.cy + innerR * sin(na))
        let end    = CGPoint(x: g.cx + outerR * cos(na), y: g.cy + outerR * sin(na))

        Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
        .stroke(ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .shadow(color: .black.opacity(shadowAlpha), radius: 2, y: 1)
        .animation(.spring(duration: 0.55, bounce: 0.15), value: needleFrac)

        Circle()
            .fill(ink)
            .overlay(Circle().fill(.black.opacity(0.15)).frame(width: 4, height: 4))
            .shadow(color: .black.opacity(shadowAlpha), radius: 2, y: 1)
            .frame(width: 14, height: 14)
            .position(x: g.cx, y: g.cy)
    }

    @ViewBuilder
    private func gaugeReadout(g: Geo) -> some View {
        let bigText = balance > 0
            ? "+\(abs(Int(balance)).formatted())"
            : "\(abs(Int(balance)).formatted())"
        VStack(spacing: 2) {
            Text(bigText)
                .font(.system(size: 30, weight: .light))
                .monospacedDigit()
                .foregroundStyle(zoneColour)
                .contentTransition(.numericText(countsDown: balance > 0))
                .animation(.spring(duration: 0.4), value: balance)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(zoneColour.opacity(0.75))
        }
        .position(x: g.cx, y: g.cy - g.r * 0.55)
    }

    @ViewBuilder
    private func gaugeEndLabels(g: Geo) -> some View {
        Text("deficit")
            .font(.system(size: 9, weight: .medium)).tracking(0.5).textCase(.uppercase)
            .foregroundStyle(deficitCol.opacity(0.85))
            .position(x: g.cx - g.r + g.tw * 0.3, y: g.cy + g.tw / 2 + 12)
        Text("surplus")
            .font(.system(size: 9, weight: .medium)).tracking(0.5).textCase(.uppercase)
            .foregroundStyle(surplusCol.opacity(0.85))
            .position(x: g.cx + g.r - g.tw * 0.3, y: g.cy + g.tw / 2 + 12)
    }
}

// MARK: - Mini macro chart (small multiples)

private struct MiniMacroChart: View {
    let label: String
    let data: [BurndownPoint]
    let goal: Double
    let color: Color
    let xDomain: ClosedRange<Date>
    var showPct: Bool = false

    private var currentVal: Double { data.last?.value ?? 0 }
    private var pct: Int { goal > 0 ? Int((currentVal / goal * 100).rounded()) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: label + value on left, remaining on right
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))

                Text(showPct ? "\(pct)%" : "\(Int(currentVal))g")
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: showPct)

                Spacer()

                let remaining = max(0, goal - currentVal)
                let remainPct = goal > 0 ? Int((remaining / goal * 100).rounded()) : 0
                Text(showPct ? "\(remainPct)% left" : "\(Int(remaining))g left")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: showPct)
            }

            // Full-width chart
            Chart {
                ForEach(data) { pt in
                    AreaMark(x: .value("T", pt.time), y: .value("g", pt.value))
                        .foregroundStyle(LinearGradient(
                            colors: [color.opacity(0.30), color.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
                ForEach(data) { pt in
                    LineMark(x: .value("T", pt.time), y: .value("g", pt.value))
                        .foregroundStyle(color.opacity(0.9))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("goal", goal))
                    .foregroundStyle(color.opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: 0...max(goal * 1.15, 1))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 72)
        }
    }
}

struct MacroBar: View {
    let label: String
    let left: Double
    let goal: Double
    let barColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 48, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(barColor)
                        .frame(width: geo.size.width * max(0.02, left / max(goal, 1)))
                        .animation(.spring(duration: 0.6, bounce: 0.2), value: left)
                }
            }
            .frame(height: 10)
            Text("\(Int(left))g left")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 58, alignment: .trailing)
        }
    }
}

// MARK: - Button style

struct GlassButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
