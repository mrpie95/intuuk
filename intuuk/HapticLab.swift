//
//  HapticLab.swift
//
//  Self-contained haptic experimentation kit. Drop this single file into any
//  iOS 13+ project — no project-specific dependencies. Uses CoreHaptics
//  (CHHapticEngine) so it can do things UIImpactFeedbackGenerator can't:
//  parameter curves, sustained continuous events, custom intensity/sharpness.
//
//  Quick start:
//      HapticLab.shared.sineWave(duration: 3, frequency: 2)
//      HapticLab.shared.sweep(from: 0, to: 1, duration: 2)
//      HapticLab.shared.tap(intensity: 0.8, sharpness: 0.3)
//      HapticLab.shared.stop()
//
//  Or, drop the bundled `HapticLabView` into your dev menu for a live
//  playground with sliders + sine-wave preview:
//      NavigationLink("Haptic lab") { HapticLabView() }
//

import CoreHaptics
import Foundation
import SwiftUI

final class HapticLab {

    static let shared = HapticLab()

    // MARK: - Engine lifecycle

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private init() { setupEngine() }

    private func setupEngine() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            // Auto-restart if iOS resets us (audio session changes, etc.)
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { reason in
                #if DEBUG
                print("HapticLab engine stopped:", reason.rawValue)
                #endif
            }
            try engine?.start()
        } catch {
            #if DEBUG
            print("HapticLab init error:", error)
            #endif
        }
    }

    /// Cancel anything currently playing and ready the engine for the next pattern.
    func stop() {
        engine?.stop()
        try? engine?.start()
    }

    // MARK: - Patterns

    /// Continuous oscillation following a sine wave.
    /// You can literally feel the wave breathing through the Taptic Engine.
    ///
    /// - Parameters:
    ///   - duration: Total length in seconds.
    ///   - frequency: Hz of the sine wave (cycles per second). 1–4 Hz feels best.
    ///   - minIntensity: Wave trough (0…1).
    ///   - maxIntensity: Wave peak (0…1).
    ///   - sharpness: Tactile texture (0=dull thud, 1=crisp click).
    ///   - resolution: Control points per second sampled along the curve.
    ///                 60 is silky; 30 is fine; below 15 you start to feel steps.
    func sineWave(duration: TimeInterval = 3.0,
                  frequency: Double      = 2.0,
                  minIntensity: Float    = 0.0,
                  maxIntensity: Float    = 1.0,
                  sharpness: Float       = 0.5,
                  resolution: Int        = 60) {

        let totalSamples = max(1, Int(duration * Double(resolution)))
        var points: [CHHapticParameterCurve.ControlPoint] = []
        points.reserveCapacity(totalSamples + 1)

        for i in 0...totalSamples {
            let t = Double(i) / Double(resolution)
            let phase = 2 * .pi * frequency * t
            // Map sin(-1…1) → 0…1 so we never invert intensity
            let normalized = (sin(phase) + 1) / 2
            let value = minIntensity + (maxIntensity - minIntensity) * Float(normalized)
            points.append(.init(relativeTime: t, value: value))
        }

        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: points,
            relativeTime: 0
        )

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: maxIntensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )

        play(events: [event], curves: [intensityCurve])
    }

    /// Linear sweep from one intensity to another. Great for "charging up"
    /// or "winding down" feedback.
    func sweep(duration: TimeInterval = 2.0,
               from start: Float       = 0.0,
               to end: Float           = 1.0,
               sharpness: Float        = 0.5) {

        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0,        value: start),
                .init(relativeTime: duration, value: end),
            ],
            relativeTime: 0
        )

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: max(start, end)),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )

        play(events: [event], curves: [curve])
    }

    /// Steady continuous rumble at constant intensity.
    func rumble(duration: TimeInterval = 1.0,
                intensity: Float       = 0.5,
                sharpness: Float       = 0.3) {

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )
        play(events: [event], curves: [])
    }

    /// One-shot tap. Like UIImpactFeedbackGenerator but with full control over
    /// intensity AND sharpness (UIImpact only exposes intensity).
    func tap(intensity: Float = 1.0, sharpness: Float = 1.0) {
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        play(events: [event], curves: [])
    }

    // MARK: - Internal player

    private func play(events: [CHHapticEvent],
                      curves: [CHHapticParameterCurve]) {
        guard supportsHaptics else { return }
        guard let engine else { return }

        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            // Engine may have stopped (backgrounded, audio interruption) —
            // start() is idempotent and cheap if already running.
            try engine.start()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            #if DEBUG
            print("HapticLab play error:", error)
            #endif
        }
    }
}

// MARK: - HapticLabView (optional companion playground UI)
//
// A SwiftUI playground with a single unified intensity-vs-time graph at the
// top, a pattern picker, and adaptive parameter controls below. Intended for
// dev menus. Drop into a NavigationStack:
//     NavigationLink("Haptic lab") { HapticLabView() }

/// All four built-in patterns share one abstraction: an intensity function
/// f(t) → 0…1 over a duration. The graph plots this; playback fires it.
enum HapticPattern: String, CaseIterable, Identifiable {
    case sine, sweep, rumble, tap

    var id:    String { rawValue }
    var label: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .sine:   return "wave.3.right"
        case .sweep:  return "chart.line.uptrend.xyaxis"
        case .rumble: return "speaker.wave.3.fill"
        case .tap:    return "hand.tap.fill"
        }
    }
    var color: Color {
        switch self {
        case .sine:   return .accentColor
        case .sweep:  return .green
        case .rumble: return .orange
        case .tap:    return .pink
        }
    }
}

struct HapticLabView: View {

    @State private var pattern: HapticPattern = .sine

    // MARK: Per-pattern parameters
    @State private var sineDuration:    Double = 3.0
    @State private var sineFrequency:   Double = 2.0
    @State private var sineMinIntensity: Double = 0.0
    @State private var sineMaxIntensity: Double = 1.0
    @State private var sineSharpness:   Double = 0.5

    @State private var sweepDuration:  Double = 2.0
    @State private var sweepFrom:      Double = 0.0
    @State private var sweepTo:        Double = 1.0
    @State private var sweepSharpness: Double = 0.5

    @State private var rumbleDuration:  Double = 1.5
    @State private var rumbleIntensity: Double = 0.5
    @State private var rumbleSharpness: Double = 0.3

    @State private var tapIntensity: Double = 1.0
    @State private var tapSharpness: Double = 1.0

    // MARK: Playback state — wall-clock instant for the TimelineView playhead
    @State private var playbackStart: Date? = nil

    // MARK: Derived from current pattern

    /// X-axis range of the graph. Tap is instantaneous so we frame 0.5s of
    /// timeline so the spike is legible.
    private var graphDuration: Double {
        switch pattern {
        case .sine:   return sineDuration
        case .sweep:  return sweepDuration
        case .rumble: return rumbleDuration
        case .tap:    return 0.5
        }
    }

    /// Pure intensity function for the current pattern. The graph plots
    /// this and the playhead samples it for the dot's vertical position.
    /// Captured into a stable closure so the graph re-evaluates per frame.
    private var intensityFunction: (Double) -> Double {
        switch pattern {
        case .sine:
            let f = sineFrequency, lo = sineMinIntensity, hi = sineMaxIntensity
            return { t in
                let n = (sin(2 * .pi * f * t) + 1) / 2
                return lo + (hi - lo) * n
            }
        case .sweep:
            let dur = sweepDuration, from = sweepFrom, to = sweepTo
            return { t in
                let p = max(0, min(1, t / dur))
                return from + (to - from) * p
            }
        case .rumble:
            let v = rumbleIntensity
            return { _ in v }
        case .tap:
            let v = tapIntensity
            // Visualised as a quick spike (~30ms) so the dot drops off
            // immediately — matches the perceptual reality of a transient.
            return { t in t < 0.03 ? v : 0 }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Unified graph ───────────────────────────────
                HapticGraph(
                    duration:      graphDuration,
                    intensity:     intensityFunction,
                    accent:        pattern.color,
                    playbackStart: playbackStart
                )
                .frame(height: 180)

                // ── Pattern picker ──────────────────────────────
                Picker("Pattern", selection: $pattern) {
                    ForEach(HapticPattern.allCases) { p in
                        Label(p.label, systemImage: p.systemImage).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                // ── Pattern-specific settings ───────────────────
                Group {
                    switch pattern {
                    case .sine:   sineSettings
                    case .sweep:  sweepSettings
                    case .rumble: rumbleSettings
                    case .tap:    tapSettings
                    }
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // ── Play + Stop ─────────────────────────────────
                playButton
                stopButton
            }
            .padding(20)
        }
        .navigationTitle("Haptic Lab")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: pattern)
    }

    // MARK: - Per-pattern settings

    @ViewBuilder private var sineSettings: some View {
        paramSlider("Duration",   value: $sineDuration,    range: 0.3...10, unit: "s")
        paramSlider("Frequency",  value: $sineFrequency,   range: 0.1...10, unit: "Hz")
        paramSlider("Min int.",   value: $sineMinIntensity, range: 0...1)
        paramSlider("Max int.",   value: $sineMaxIntensity, range: 0...1)
        paramSlider("Sharpness",  value: $sineSharpness,   range: 0...1)
    }

    @ViewBuilder private var sweepSettings: some View {
        paramSlider("Duration",   value: $sweepDuration,  range: 0.2...5, unit: "s")
        paramSlider("From",       value: $sweepFrom,      range: 0...1)
        paramSlider("To",         value: $sweepTo,        range: 0...1)
        paramSlider("Sharpness",  value: $sweepSharpness, range: 0...1)
    }

    @ViewBuilder private var rumbleSettings: some View {
        paramSlider("Duration",   value: $rumbleDuration,  range: 0.1...5, unit: "s")
        paramSlider("Intensity",  value: $rumbleIntensity, range: 0...1)
        paramSlider("Sharpness",  value: $rumbleSharpness, range: 0...1)
    }

    @ViewBuilder private var tapSettings: some View {
        paramSlider("Intensity",  value: $tapIntensity, range: 0...1)
        paramSlider("Sharpness",  value: $tapSharpness, range: 0...1)
    }

    // MARK: - Buttons

    private var playButton: some View {
        Button {
            firePattern()
        } label: {
            Label("Play \(pattern.label.lowercased())", systemImage: "play.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(pattern.color)
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            HapticLab.shared.stop()
            playbackStart = nil
        } label: {
            Label("Stop", systemImage: "stop.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Slider helper

    private func paramSlider(_ label: String,
                             value: Binding<Double>,
                             range: ClosedRange<Double>,
                             unit: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedValue(value.wrappedValue, unit: unit))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Slider(value: value, in: range)
                .tint(pattern.color)
        }
    }

    private func formattedValue(_ v: Double, unit: String) -> String {
        let formatted = String(format: v < 10 ? "%.2f" : "%.1f", v)
        return unit.isEmpty ? formatted : "\(formatted) \(unit)"
    }

    // MARK: - Playback dispatch

    /// Routes the current pattern's params to HapticLab + starts the playhead.
    private func firePattern() {
        let dur = graphDuration
        switch pattern {
        case .sine:
            HapticLab.shared.sineWave(
                duration:     sineDuration,
                frequency:    sineFrequency,
                minIntensity: Float(sineMinIntensity),
                maxIntensity: Float(sineMaxIntensity),
                sharpness:    Float(sineSharpness)
            )
        case .sweep:
            HapticLab.shared.sweep(
                duration:  sweepDuration,
                from:      Float(sweepFrom),
                to:        Float(sweepTo),
                sharpness: Float(sweepSharpness)
            )
        case .rumble:
            HapticLab.shared.rumble(
                duration:  rumbleDuration,
                intensity: Float(rumbleIntensity),
                sharpness: Float(rumbleSharpness)
            )
        case .tap:
            HapticLab.shared.tap(
                intensity: Float(tapIntensity),
                sharpness: Float(tapSharpness)
            )
        }
        playbackStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            // Only clear if no newer playback has started in the meantime
            if let start = playbackStart, Date().timeIntervalSince(start) >= dur {
                playbackStart = nil
            }
        }
    }
}

// MARK: - HapticGraph (general-purpose intensity-over-time plot)
//
// Pattern-agnostic: takes a duration and a closure that maps time → intensity.
// The graph just plots f(t) and (when playing) renders a playhead that
// samples the same f(t) on every frame so the dot tracks exactly.

private struct HapticGraph: View {

    let duration:      Double
    let intensity:     (Double) -> Double
    let accent:        Color
    let playbackStart: Date?

    private let leftPad:   CGFloat = 28
    private let bottomPad: CGFloat = 18
    private let topPad:    CGFloat = 6
    private let rightPad:  CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let plotW = geo.size.width  - leftPad - rightPad
            let plotH = geo.size.height - topPad  - bottomPad

            ZStack(alignment: .topLeading) {
                gridAndAxes(plotW: plotW, plotH: plotH)
                curveFill(plotW: plotW, plotH: plotH)
                curveStroke(plotW: plotW, plotH: plotH)
                playhead(plotW: plotW, plotH: plotH)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
    }

    // MARK: - Layers

    @ViewBuilder
    private func gridAndAxes(plotW: CGFloat, plotH: CGFloat) -> some View {
        // Horizontal gridlines + Y labels
        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { y in
            let yPos = topPad + plotH * (1 - CGFloat(y))
            Path { p in
                p.move(to:    .init(x: leftPad,         y: yPos))
                p.addLine(to: .init(x: leftPad + plotW, y: yPos))
            }
            .stroke(.secondary.opacity(0.15), lineWidth: 0.5)

            if y == 0 || y == 0.5 || y == 1.0 {
                Text(String(format: "%.1f", y))
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: leftPad - 4, alignment: .trailing)
                    .position(x: (leftPad - 4) / 2, y: yPos)
            }
        }

        // X-axis ticks + time labels
        let ticks = 4
        ForEach(0...ticks, id: \.self) { i in
            let frac = Double(i) / Double(ticks)
            let xPos = leftPad + plotW * CGFloat(frac)
            Path { p in
                p.move(to:    .init(x: xPos, y: topPad + plotH))
                p.addLine(to: .init(x: xPos, y: topPad + plotH + 3))
            }
            .stroke(.secondary.opacity(0.5), lineWidth: 0.5)

            Text(String(format: duration < 1 ? "%.2fs" : "%.1fs", duration * frac))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .position(x: xPos, y: topPad + plotH + 10)
        }
    }

    private func curveFill(plotW: CGFloat, plotH: CGFloat) -> some View {
        var p = curvePath(width: plotW, height: plotH)
        p.addLine(to: .init(x: plotW, y: plotH))
        p.addLine(to: .init(x: 0,     y: plotH))
        p.closeSubpath()
        return p
            .offset(x: leftPad, y: topPad)
            .fill(
                LinearGradient(
                    colors: [accent.opacity(0.35), accent.opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    private func curveStroke(plotW: CGFloat, plotH: CGFloat) -> some View {
        curvePath(width: plotW, height: plotH)
            .offset(x: leftPad, y: topPad)
            .stroke(
                accent,
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )
    }

    @ViewBuilder
    private func playhead(plotW: CGFloat, plotH: CGFloat) -> some View {
        if let start = playbackStart {
            // TimelineView gives us ~60fps redraws driven by the system clock.
            // We re-evaluate the intensity function fresh each frame so the
            // dot tracks the curve EXACTLY (no SwiftUI interpolation between
            // sample points, which is what made earlier attempts wrong).
            TimelineView(.animation) { context in
                let elapsed  = context.date.timeIntervalSince(start)
                let progress = max(0, min(1, elapsed / duration))
                let xPos     = leftPad + plotW * CGFloat(progress)

                let value = max(0, min(1, intensity(elapsed)))
                let yPos  = topPad + plotH * (1 - CGFloat(value))

                ZStack {
                    Path { path in
                        path.move(to:    .init(x: xPos, y: topPad))
                        path.addLine(to: .init(x: xPos, y: topPad + plotH))
                    }
                    .stroke(Color.red.opacity(0.85), lineWidth: 1.5)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .position(x: xPos, y: yPos)
                }
            }
        }
    }

    // MARK: - Curve sampler

    /// Plots f(t) by sampling once per pixel of the plot's width.
    private func curvePath(width w: CGFloat, height h: CGFloat) -> Path {
        Path { p in
            let samples = max(60, Int(w))
            for i in 0...samples {
                let frac  = Double(i) / Double(samples)
                let t     = duration * frac
                let value = max(0, min(1, intensity(t)))
                let x = CGFloat(frac) * w
                let y = h - CGFloat(value) * h
                if i == 0 { p.move(to: .init(x: x, y: y)) }
                else      { p.addLine(to: .init(x: x, y: y)) }
            }
        }
    }
}
