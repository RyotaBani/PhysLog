import Foundation

enum CSVImporter {

    enum ImportError: LocalizedError {
        case unreadable
        case noRows

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "ファイルを読み取れませんでした。CSV形式のファイルを選んでください。"
            case .noRows:
                return "取り込める行が見つかりませんでした。"
            }
        }
    }

    struct Parsed {
        var headers: [String]
        var rows: [[String]]
        var encodingName: String
    }

    // MARK: - 読み込み

    /// 日本の測定機器が出すCSVは Shift_JIS が多いため、順に試して読めた方を採用する。
    /// UTF-8 決め打ちにすると業務用タニタの出力が文字化けする。
    static func read(url: URL) throws -> Parsed {
        let needsRelease = url.startAccessingSecurityScopedResource()
        defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }

        let candidates: [(String.Encoding, String)] = [
            (.utf8, "UTF-8"),
            (.shiftJIS, "Shift_JIS"),
            (.japaneseEUC, "EUC-JP"),
            (.utf16, "UTF-16")
        ]

        var text: String?
        var encodingName = ""
        for (enc, name) in candidates {
            if let s = String(data: data, encoding: enc), !s.isEmpty {
                // 文字化けの簡易判定。置換文字が多い場合は次の候補へ。
                let broken = s.filter { $0 == "\u{FFFD}" }.count
                if broken * 200 < s.count {
                    text = s
                    encodingName = name
                    break
                }
            }
        }
        guard var body = text else { throw ImportError.unreadable }

        // BOM を除去
        if body.hasPrefix("\u{FEFF}") { body.removeFirst() }

        let lines = splitRows(body)
        guard let first = lines.first, lines.count >= 2 else { throw ImportError.noRows }

        return Parsed(headers: first, rows: Array(lines.dropFirst()), encodingName: encodingName)
    }

    // MARK: - パース

    /// 引用符・引用符内の改行・エスケープされた引用符に対応した簡易パーサ
    static func splitRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character?

        func endField() { row.append(field.trimmingCharacters(in: .whitespaces)); field = "" }
        func endRow() {
            endField()
            if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
            row = []
        }

        while let ch = pending ?? iterator.next() {
            pending = nil

            if inQuotes {
                if ch == "\"" {
                    // 連続する引用符は文字としての引用符
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
                continue
            }

            switch ch {
            case "\"": inQuotes = true
            case ",", "\t": endField()
            // Swift では "\r\n" が1つの Character として扱われるため、
            // "\r" や "\n" との比較では一致しない。isNewline でまとめて判定する。
            case _ where ch.isNewline: endRow()
            default: field.append(ch)
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    // MARK: - 行の変換

    /// 列の対応づけに従って ImportRow へ変換する
    static func buildRows(from parsed: Parsed, mapping: [ImportField]) -> [ImportRow] {
        parsed.rows.compactMap { cols in
            var row = ImportRow()
            row.rawLine = cols.joined(separator: ", ")

            for (i, field) in mapping.enumerated() {
                guard i < cols.count else { continue }
                let value = cols[i]
                guard !value.isEmpty else { continue }

                switch field {
                case .date:       row.date = ValueParser.date(value)
                case .weight:     row.weight = ValueParser.number(value)
                case .bodyFat:    row.bodyFat = ValueParser.number(value)
                case .muscleMass: row.muscleMass = ValueParser.number(value)
                case .skip:       break
                }
            }
            return row.hasValue ? row : nil
        }
    }
}
