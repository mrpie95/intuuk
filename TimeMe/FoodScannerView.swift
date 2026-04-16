import SwiftUI
import AVFoundation
import Vision
import Combine

// MARK: - Scanner engine

final class NutritionScanner: NSObject, ObservableObject {
    @Published var protein:    Double? = nil
    @Published var carbs:      Double? = nil
    @Published var fat:        Double? = nil
    @Published var basisGrams: Double  = 100   // always the per-Xg reference; user enters actual grams
    @Published var confidence: Double  = 0
    @Published var isLocked:   Bool    = false

    let session = AVCaptureSession()
    private let videoOutput    = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "nutrition.scanner", qos: .userInitiated)

    private struct Reading { var protein, carbs, fat: Double?; var kcal: Double?; var basis: Double = 100 }
    private var window: [Reading] = []
    private let windowSize   = 8
    private let lockRequired = 5   // need 5-of-8 consistent reads
    private var frameIndex   = 0

    // MARK: Lifecycle

    func start() {
        processingQueue.async {
            if self.session.inputs.isEmpty {
                self.configureSession()                // first time → set up + start
            } else if !self.session.isRunning {
                self.session.startRunning()            // already configured → just resume
            }
        }
    }

    func stop() {
        processingQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func resetForRescan() {
        window     = []
        frameIndex = 0
        DispatchQueue.main.async {
            self.isLocked   = false
            self.confidence = 0
            self.protein    = nil
            self.carbs      = nil
            self.fat        = nil
            self.basisGrams = 100
        }
    }

    // MARK: Session setup

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { session.commitConfiguration(); return }

        session.addInput(input)
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()
        session.startRunning()
    }

    // MARK: Text parsing
    //
    // Strategy: cluster OCR observations into VISUAL ROWS by Y-coordinate, then
    // match each row's joined text against macro keywords. Immune to OCR read-order
    // (row-major vs column-major tables), label wrapping, and observation splits.
    // Cross-validates via kcal: protein×4 + carbs×4 + fat×9 ≈ labelled kcal (±25 %).

    private struct LabelRow {
        let text:       String    // lowercased, comma → dot, left-to-right joined
        let firstValue: Double?   // first gram value found in the row, if any
    }

    private func parseObservations(_ obs: [VNRecognizedTextObservation]) -> Reading {
        let rows    = groupIntoRows(obs)
        let allText = rows.map(\.text).joined(separator: " ")

        var r = Reading()
        r.basis = parseBasis(from: [allText])
        r.kcal  = extractKcal(from: [allText])

        for row in rows {
            // Reject sub-rows (waarvan / of which / davon / di cui …) up-front.
            guard !isSubRow(row.text) else { continue }
            // Each macro row must carry a plausible gram value (0 < v ≤ 100g / 100g).
            guard let value = row.firstValue, value > 0, value <= 100 else { continue }

            if      r.fat     == nil, matchesFat(row.text)     { r.fat     = value }
            else if r.carbs   == nil, matchesCarbs(row.text)   { r.carbs   = value }
            else if r.protein == nil, matchesProtein(row.text) { r.protein = value }

            if r.fat != nil, r.carbs != nil, r.protein != nil { break }
        }
        return r
    }

    /// Cluster observations into visual rows by Y-coordinate proximity.
    /// Within each row, parts are concatenated left-to-right so the row text reads naturally.
    private func groupIntoRows(_ obs: [VNRecognizedTextObservation]) -> [LabelRow] {
        struct Part { let text: String; let midY: CGFloat; let minX: CGFloat }
        let parts: [Part] = obs.compactMap { o in
            guard let t = o.topCandidates(1).first?.string else { return nil }
            return Part(text: t, midY: o.boundingBox.midY, minX: o.boundingBox.minX)
        }
        // 1.3 % of image height — tight enough to keep adjacent rows separate,
        // loose enough to tolerate the slight Y offset between label/value columns.
        let yTol: CGFloat = 0.013
        var buckets: [(midY: CGFloat, items: [Part])] = []
        for part in parts {
            if let i = buckets.firstIndex(where: { abs($0.midY - part.midY) < yTol }) {
                buckets[i].items.append(part)
            } else {
                buckets.append((part.midY, [part]))
            }
        }
        // Top-first (higher midY first in Vision coords), then left-to-right within a row.
        return buckets
            .sorted { $0.midY > $1.midY }
            .map { bucket in
                let joined = bucket.items
                    .sorted { $0.minX < $1.minX }
                    .map(\.text)
                    .joined(separator: " ")
                    .lowercased()
                    .replacingOccurrences(of: ",", with: ".")
                return LabelRow(text: joined, firstValue: firstGramValue(in: joined))
            }
    }

    // MARK: Sub-row filter (rejects "of which" / "waarvan" / "davon" / …).

    private func isSubRow(_ line: String) -> Bool {
        let markers = [
            "of which", "of that", "saturate", "including",   // English
            "waarvan",                                         // Dutch
            "dont",                                            // French
            "davon",                                           // German
            "di cui",                                          // Italian
            "de los cuales", "de las cuales", "dos quais",     // Spanish / Portuguese
            "heraf", "varav", "josta",                         // Scandinavian
            "w tym",                                           // Polish
            "z toho", "z nichž",                               // Czech / Slovak
            "ebből",                                           // Hungarian
            "- of", "w.o."                                     // misc
        ]
        return markers.contains { line.contains($0) }
    }

    // MARK: Macro classifiers
    //
    // Short ambiguous roots (`vet`, `fat`, `fett`, `fedt`, `eiwit`) use word boundaries so
    // sub-row variants like `vetzuren` (Dutch: saturated fatty acids) or `fettsäuren`
    // (German) can't accidentally match the total-fat row. Longer keywords are safe as
    // substrings.

    private func matchesFat(_ line: String) -> Bool {
        if line.contains(#/\b(vet|fat|fett|fedt|tuk)\b/#) { return true }
        let keywords = ["total fat",
                        "grasas", "lipides", "graisse", "matières grasses",
                        "lipidit", "tłuszcz"]
        return keywords.contains { line.contains($0) }
    }

    private func matchesCarbs(_ line: String) -> Bool {
        let keywords = [
            "carbohydrate", "carbs",
            "koolhydraten", "koolhydraat",
            "glucides", "kohlenhydrate", "kohlenhydrat",
            "hidratos",                                        // covers "hidratos de carbono"
            "carboidrat",
            "kulhydrat", "kolhydrater", "hiilihydraatit",
            "węglowodan", "sacharidy"
        ]
        return keywords.contains { line.contains($0) }
    }

    private func matchesProtein(_ line: String) -> Bool {
        if line.contains(#/\beiwit(?:ten)?\b/#) { return true }   // Dutch
        let keywords = ["protein",
                        "eiweiß", "eiweiss",
                        "protéines", "proteínas", "proteine",
                        "białko", "bílkoviny"]
        return keywords.contains { line.contains($0) }
    }

    private func firstGramValue(in text: String) -> Double? {
        if let m = text.firstMatch(of: #/(\d+\.?\d*)\s*g(?:[^a-z]|$)/#) {
            return Double(m.output.1)
        }
        return nil
    }

    // MARK: Basis & kcal extraction

    /// Returns the gram weight the label values are based on (e.g. 100 for per-100g, 30 for a 30g serving).
    /// We always present values as per-Xg so the user can enter actual grams consumed.
    private func parseBasis(from texts: [String]) -> Double {
        let joined = texts.joined(separator: " ").lowercased().replacingOccurrences(of: ",", with: ".")

        // ── Step 1: explicit per-serving descriptors ─────────────
        // These define a specific serving size, so we honour them even when the
        // value isn't 100g (e.g. "serving size 40g", "portie 30g").
        let servingPatterns: [Regex<(Substring, Substring)>] = [
            #/(?:serving size|portion size|portie|porzione|ration|portionsgröße)[^\d]*(\d+\.?\d*)\s*g/#,
            #/per\s+(?:serving|portie|portion)[^\d]*(\d+\.?\d*)\s*g/#,
            #/serv\.\s*size[^\d]*(\d+\.?\d*)\s*g/#,
        ]
        for p in servingPatterns {
            if let m = joined.firstMatch(of: p), let v = Double(m.output.1), v > 5 { return v }
        }

        // ── Step 2: "per Xg" / "per X gram" reference weight ─────
        // Anchoring to "per" prevents matching standalone product net weights
        // like "300g e" (EU estimated weight mark) or "(300g)" on the packaging.
        let perPatterns: [Regex<(Substring, Substring)>] = [
            #/per\s*\((\d+\.?\d*)\s*g\)/#,            // per (100g)
            #/per\s+(\d+\.?\d*)\s*g(?:ram)?\b/#,       // per 100g  /  per 100 gram
        ]
        for p in perPatterns {
            if let m = joined.firstMatch(of: p), let v = Double(m.output.1), v > 5 { return v }
        }

        // Default — EU nutrition labels without an explicit reference are per 100g.
        return 100
    }

    /// Extract kcal value for cross-validation (e.g. "559 kcal" or "559kcal").
    private func extractKcal(from texts: [String]) -> Double? {
        let joined = texts.joined(separator: " ").lowercased().replacingOccurrences(of: ",", with: ".")
        if let m = joined.firstMatch(of: #/(\d+\.?\d*)\s*kcal/#) { return Double(m.output.1) }
        return nil
    }

    /// True when P×4 + C×4 + F×9 is within 25 % of the parsed kcal.
    /// If kcal is unavailable, always returns true (can't validate).
    private func caloriesOK(p: Double, c: Double, f: Double, kcal: Double?) -> Bool {
        guard let k = kcal, k > 0 else { return true }
        let calc = p * 4 + c * 4 + f * 9
        return abs(calc - k) <= max(k * 0.25, 30)
    }

    // MARK: Stability window

    private func updateWindow(_ reading: Reading) {
        window.append(reading)
        if window.count > windowSize { window.removeFirst() }

        guard !isLocked else { return }

        let proteins = window.compactMap { $0.protein }
        let carbsArr = window.compactMap { $0.carbs }
        let fatsArr  = window.compactMap { $0.fat }

        // Live preview — show latest detected values immediately
        let liveP = proteins.last
        let liveC = carbsArr.last
        let liveF = fatsArr.last

        guard proteins.count >= 2 || carbsArr.count >= 2 else {
            publish(conf: Double(max(proteins.count, carbsArr.count)) / Double(windowSize),
                    p: liveP, c: liveC, f: liveF)
            return
        }

        let medP = median(proteins)
        let medC = median(carbsArr)
        let medF = median(fatsArr)

        let stableP = proteins.filter { abs($0 - (medP ?? 0)) <= 3 }.count
        let stableC = carbsArr.filter { abs($0 - (medC ?? 0)) <= 5 }.count
        let stableF = fatsArr.filter  { abs($0 - (medF ?? 0)) <= 3 }.count

        // Lock when 2 of 3 macros are stable — missing values default to 0
        // (EU labelling requires all three; 0 means genuinely absent, not unread)
        let stableCount = [stableP >= lockRequired,
                           stableC >= lockRequired,
                           stableF >= lockRequired].filter { $0 }.count
        let conf = Double(max(stableP, stableC, stableF)) / Double(lockRequired)

        if stableCount >= 2 {
            let p = medP ?? 0; let c = medC ?? 0; let f = medF ?? 0
            let medKcal = median(window.compactMap { $0.kcal })
            // Cross-validate: if macros don't add up to kcal, don't lock — keep scanning
            guard caloriesOK(p: p, c: c, f: f, kcal: medKcal) else {
                publish(conf: min(conf, 0.85), p: liveP, c: liveC, f: liveF,
                        basis: window.last?.basis ?? 100)
                return
            }
            let last = window.last
            DispatchQueue.main.async {
                self.protein    = p
                self.carbs      = c
                self.fat        = f
                self.basisGrams = last?.basis ?? 100
                self.confidence = 1
                self.isLocked   = true
            }
            // Triple-pulse "captured" cue — distinguishes lock from a regular tap.
            hapticPulse(times: 3, style: .medium, interval: 0.08)
        } else {
            publish(conf: min(conf, 0.92), p: liveP, c: liveC, f: liveF,
                    basis: window.last?.basis ?? 100)
        }
    }

    private func publish(conf: Double, p: Double?, c: Double?, f: Double?, basis: Double = 100) {
        DispatchQueue.main.async {
            self.confidence = conf
            self.protein    = p
            self.carbs      = c
            self.fat        = f
            self.basisGrams = basis
        }
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.sorted()[values.count / 2]
    }
}

extension NutritionScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameIndex += 1
        guard frameIndex % 3 == 0 else { return } // ~10 fps OCR
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self,
                  let obs = req.results as? [VNRecognizedTextObservation]
            else { return }
            self.updateWindow(self.parseObservations(obs))
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
    }
}

// MARK: - Camera preview (UIKit bridge)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> _PreviewView {
        let v = _PreviewView()
        v.previewLayer.session      = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: _PreviewView, context: Context) {}

    class _PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Bracket corner shape

struct ScanBracketsShape: Shape {
    private let arm: CGFloat = 28
    private let r:   CGFloat = 5

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        p.move(to: CGPoint(x: minX, y: minY + arm))
        p.addLine(to: CGPoint(x: minX, y: minY + r))
        p.addQuadCurve(to: CGPoint(x: minX + r, y: minY), control: CGPoint(x: minX, y: minY))
        p.addLine(to: CGPoint(x: minX + arm, y: minY))

        p.move(to: CGPoint(x: maxX - arm, y: minY))
        p.addLine(to: CGPoint(x: maxX - r, y: minY))
        p.addQuadCurve(to: CGPoint(x: maxX, y: minY + r), control: CGPoint(x: maxX, y: minY))
        p.addLine(to: CGPoint(x: maxX, y: minY + arm))

        p.move(to: CGPoint(x: maxX, y: maxY - arm))
        p.addLine(to: CGPoint(x: maxX, y: maxY - r))
        p.addQuadCurve(to: CGPoint(x: maxX - r, y: maxY), control: CGPoint(x: maxX, y: maxY))
        p.addLine(to: CGPoint(x: maxX - arm, y: maxY))

        p.move(to: CGPoint(x: minX + arm, y: maxY))
        p.addLine(to: CGPoint(x: minX + r, y: maxY))
        p.addQuadCurve(to: CGPoint(x: minX, y: maxY - r), control: CGPoint(x: minX, y: maxY))
        p.addLine(to: CGPoint(x: minX, y: maxY - arm))
        return p
    }
}

