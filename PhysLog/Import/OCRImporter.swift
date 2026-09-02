import Foundation

#if canImport(Vision)
import Vision
import UIKit
#endif

/// 測定結果の画像から数値を読み取る。
///
/// 対象は2つ。
///   1. ジムのInBody・タニタ業務用機が出す紙の結果用紙（撮影）
///   2. ヘルスプラネットやInBodyアプリの画面（スクリーンショット）
///
/// 2番目が重要で、公式にエクスポートできないサービスでも
/// 画面さえ見られれば取り込める。非公開APIに触れずに済む。
/// continuation を一度だけ再開するための小さな番人。
/// Vision の完了ハンドラと perform の例外、両方から呼ばれうるため必要。
private final class ResumeGuard: @unchecked Sendable {
    private var used = false
    private let lock = NSLock()

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}

enum OCRImporter {

    struct Result {
        var row: ImportRow
        /// 読み取れた行（利用者が確認・修正できるように全文を残す）
        var recognizedLines: [String]
        var confidence: Double
    }

    #if canImport(Vision)

    /// 端末内で完結する。画像も文字列も外部へ送信しない。
    static func scan(image: UIImage) async -> Result? {
        guard let cgImage = image.cgImage else { return nil }

        let lines: [(text: String, confidence: Float)] = await withCheckedContinuation { continuation in
            // perform が例外を投げると完了ハンドラが呼ばれないことがある。
            // その場合 continuation が再開されず処理が固まるため、
            // どちらの経路からでも一度だけ再開できるようにする。
            let guardBox = ResumeGuard()

            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let result = observations.compactMap { obs -> (String, Float)? in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    return (top.string, top.confidence)
                }
                if guardBox.claim() { continuation.resume(returning: result) }
            }
            request.recognitionLevel = .accurate
            // 日本語の結果用紙が主対象。英語表記の機種もあるため両方指定する。
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = false   // 数値が補正で崩れるのを防ぐ

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    if guardBox.claim() { continuation.resume(returning: []) }
                }
            }
        }

        guard !lines.isEmpty else { return nil }

        let texts = lines.map(\.text)
        let avgConfidence = lines.isEmpty ? 0
            : Double(lines.map(\.confidence).reduce(0, +)) / Double(lines.count)

        return Result(
            row: extract(from: texts),
            recognizedLines: texts,
            confidence: avgConfidence
        )
    }

    #endif

    // MARK: - 数値の抽出

    /// 「体重 68.5 kg」のように、項目名と数値が同じ行または隣接行に出る前提で拾う。
    /// 機種ごとにレイアウトが違うため、確実に当てにいくのではなく
    /// 「候補を出して利用者に確認してもらう」方針にしている。
    static func extract(from lines: [String]) -> ImportRow {
        var row = ImportRow()
        row.rawLine = lines.joined(separator: " / ")

        for (index, line) in lines.enumerated() {
            let norm = ColumnMapper.normalize(line)

            for field in [ImportField.weight, .bodyFat, .muscleMass] {
                guard row.value(for: field) == nil else { continue }
                guard field.keywords.contains(where: { norm.contains(ColumnMapper.normalize($0)) })
                else { continue }
                // 体脂肪「量」は別項目なので拾わない
                if norm.contains("脂肪量") { continue }

                // 同じ行の数値 → 次の行の数値 の順で探す
                if let v = firstNumber(in: line, excluding: field.keywords) {
                    row.set(v, for: field)
                } else if index + 1 < lines.count,
                          let v = firstNumber(in: lines[index + 1], excluding: []) {
                    row.set(v, for: field)
                }
            }

            if row.date == nil, let d = ValueParser.firstDate(in: line) {
                row.date = d
            }
        }

        // 日付が読めなければ当日として扱う（利用者が確認画面で直せる）
        if row.date == nil { row.date = Date() }
        return row
    }

    /// 行から最初の妥当な数値を取り出す。単位や項目名に含まれる数字は拾わない。
    private static func firstNumber(in line: String, excluding keywords: [String]) -> Double? {
        var target = line
        for k in keywords { target = target.replacingOccurrences(of: k, with: " ") }

        let pattern = #"[0-9]+\.?[0-9]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(target.startIndex..., in: target)

        for match in regex.matches(in: target, range: range) {
            guard let r = Range(match.range, in: target) else { continue }
            guard let v = Double(target[r]) else { continue }
            // 体組成の値として現実的な範囲だけ採用する
            if v > 0 && v < 400 { return v }
        }
        return nil
    }
}

// MARK: - ImportRow の項目アクセス

extension ImportRow {
    func value(for field: ImportField) -> Double? {
        switch field {
        case .weight:     return weight
        case .bodyFat:    return bodyFat
        case .muscleMass: return muscleMass
        default:          return nil
        }
    }

    mutating func set(_ value: Double, for field: ImportField) {
        switch field {
        case .weight:     weight = value
        case .bodyFat:    bodyFat = value
        case .muscleMass: muscleMass = value
        default:          break
        }
    }
}
