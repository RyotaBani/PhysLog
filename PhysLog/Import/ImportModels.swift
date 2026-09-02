import Foundation

/// 取り込める項目。CSV・OCR どちらの経路でもこの型に正規化してから保存する。
enum ImportField: String, CaseIterable, Identifiable {
    case date       = "測定日"
    case weight     = "体重"
    case bodyFat    = "体脂肪率"
    case muscleMass = "筋肉量"
    case skip       = "取り込まない"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .weight, .muscleMass: return "kg"
        case .bodyFat:             return "%"
        default:                   return ""
        }
    }

    /// 見出し文字列からの自動推定に使う手がかり。
    /// メーカーごとに表記ゆれが大きいため、日本語・英語・略記を広めに拾う。
    var keywords: [String] {
        switch self {
        case .date:
            return ["測定日", "日付", "日時", "計測日", "date", "time", "測定日時"]
        case .weight:
            return ["体重", "weight", "wt", "体重(kg)", "体重kg"]
        case .bodyFat:
            return ["体脂肪率", "体脂肪", "bodyfat", "body fat", "fat", "pbf", "体脂肪率(%)"]
        case .muscleMass:
            // InBody は「骨格筋量(SMM)」、タニタは「筋肉量」と表記が分かれる
            return ["骨格筋量", "筋肉量", "smm", "skeletal muscle", "muscle", "除脂肪", "ffm", "lbm"]
        case .skip:
            return []
        }
    }
}

/// 取り込み前の1行分。確認画面で内容を見せてから確定する。
struct ImportRow: Identifiable {
    let id = UUID()
    var date: Date?
    var weight: Double?
    var bodyFat: Double?
    var muscleMass: Double?
    /// 元データの表示用（どの行が読めなかったか分かるように残す）
    var rawLine: String = ""

    var hasValue: Bool { weight != nil || bodyFat != nil || muscleMass != nil }
    var isValid: Bool { date != nil && hasValue }

    var summary: String {
        var parts: [String] = []
        if let weight { parts.append(String(format: "%.1fkg", weight)) }
        if let bodyFat { parts.append(String(format: "%.1f%%", bodyFat)) }
        if let muscleMass { parts.append(String(format: "筋%.1fkg", muscleMass)) }
        return parts.isEmpty ? "値なし" : parts.joined(separator: " / ")
    }
}

// MARK: - 見出しの自動推定

enum ColumnMapper {

    /// 見出し行から、各列がどの項目かを推定する
    static func guessMapping(headers: [String]) -> [ImportField] {
        headers.map { header in
            let norm = normalize(header)
            guard !norm.isEmpty else { return .skip }

            // 完全一致 → 部分一致 の順で見る。
            // 「体脂肪率」と「体脂肪量」のような紛らわしい組を取り違えないため、
            // 除外語を先に弾く。
            if norm.contains("脂肪量") || norm.contains("fatmass") { return .skip }

            for field in ImportField.allCases where field != .skip {
                if field.keywords.contains(where: { normalize($0) == norm }) { return field }
            }
            for field in ImportField.allCases where field != .skip {
                if field.keywords.contains(where: { !$0.isEmpty && norm.contains(normalize($0)) }) { return field }
            }
            return .skip
        }
    }

    /// 全角・半角・大文字小文字・記号ゆれを吸収する
    static func normalize(_ s: String) -> String {
        s.applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        ?? s.lowercased()
    }
}

// MARK: - 値の解釈

enum ValueParser {

    /// 「68.5」「68.5kg」「68,5」などを数値にする
    static func number(_ raw: String) -> Double? {
        let cleaned = raw
            .applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
        let filtered = cleaned.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard !filtered.isEmpty else { return nil }
        return Double(filtered)
    }

    /// 行の中から日付らしき部分を探して解釈する。
    /// OCR では「測定日 2026/07/20」のように前後に文字が付くため、
    /// 行全体をそのまま渡しても解釈できない。
    static func firstDate(in line: String) -> Date? {
        let cleaned = (line.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? line)
        let patterns = [
            #"\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2}(\s+\d{1,2}:\d{2}(:\d{2})?)?"#,
            #"\d{4}年\d{1,2}月\d{1,2}日"#,
            #"\d{8}"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            for match in regex.matches(in: cleaned, range: range) {
                guard let r = Range(match.range, in: cleaned) else { continue }
                if let d = date(String(cleaned[r])) { return d }
            }
        }
        return nil
    }

    /// メーカーによって日付書式がばらばらなので、代表的な形をひと通り試す
    static func date(_ raw: String) -> Date? {
        let cleaned = (raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let formats = [
            "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm", "yyyy/MM/dd",
            "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd",
            "yyyy.MM.dd", "yyyyMMddHHmmss", "yyyyMMdd",
            "yyyy年MM月dd日", "yy/MM/dd"
        ]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for format in formats {
            f.dateFormat = format
            if let d = f.date(from: cleaned) { return d }
        }
        return nil
    }
}
