import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

/// CSV / OCR 共通の取り込み画面。
/// どちらの経路でも「読み取り → 対応づけ → 確認 → 保存」の流れに揃えている。
struct ImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    enum Source: Identifiable {
        case csv, photo
        var id: String { self == .csv ? "csv" : "photo" }
    }
    let source: Source

    @State private var stage: Stage = .picking
    @State private var parsed: CSVImporter.Parsed?
    @State private var mapping: [ImportField] = []
    @State private var rows: [ImportRow] = []
    @State private var recognizedLines: [String] = []
    @State private var errorMessage: String?
    @State private var showFilePicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessing = false

    enum Stage { case picking, mapping, confirming, done }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .picking:    pickingView
                case .mapping:    mappingView
                case .confirming: confirmingView
                case .done:       EmptyView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(source == .csv ? "CSVから取り込む" : "写真から取り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                if stage == .confirming {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("取り込む") { commit() }
                            .fontWeight(.semibold)
                            .disabled(validRows.isEmpty)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFile(result)
            }
            .alert("取り込めませんでした", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var validRows: [ImportRow] { rows.filter(\.isValid) }

    // MARK: - 1. 選択

    private var pickingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(source == .csv ? "対応しているファイル" : "読み取れるもの")
                            .font(.subheadline.weight(.semibold))
                        Text(source == .csv
                             ? "測定機器やアプリが書き出したCSVファイルを読み込みます。列の並びは自由です。読み込んだあとに、どの列が体重・体脂肪率・筋肉量かを指定できます。\n\nShift_JIS の日本語ファイルにも対応しています。"
                             : "InBodyやタニタ業務用機の結果用紙を撮影した写真、または体組成計アプリの画面のスクリーンショットから数値を読み取ります。\n\n読み取りは端末内で行われ、画像が外部へ送信されることはありません。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal)

                if source == .csv {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("ファイルを選ぶ", systemImage: "doc.text")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.physlogPrimary, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("写真を選ぶ", systemImage: "photo")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.physlogPrimary, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        Task { await handlePhoto(item) }
                    }
                }

                if isProcessing {
                    ProgressView("読み取っています…")
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - 2. 列の対応づけ（CSVのみ）

    private var mappingView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("列の対応を確認してください")
                            .font(.subheadline.weight(.semibold))
                        Text("見出しから自動で推定しました。違っていれば変更できます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let parsed {
                            Text("文字コード: \(parsed.encodingName) / \(parsed.rows.count)行")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal)

                if let parsed {
                    ForEach(Array(parsed.headers.enumerated()), id: \.offset) { index, header in
                        Card(padding: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(header.isEmpty ? "（見出しなし）" : header)
                                        .font(.subheadline.weight(.medium))
                                    if let sample = parsed.rows.first, index < sample.count {
                                        Text("例: \(sample[index])")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { index < mapping.count ? mapping[index] : .skip },
                                    set: { if index < mapping.count { mapping[index] = $0 } }
                                )) {
                                    ForEach(ImportField.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .labelsHidden()
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Button {
                    buildRowsFromCSV()
                } label: {
                    Text("次へ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canProceed ? Color.physlogPrimary : Color.gray,
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(!canProceed)
                .padding(.horizontal)

                if !canProceed {
                    Text("「測定日」と、体重・体脂肪率・筋肉量のいずれか1つの指定が必要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical)
        }
    }

    private var canProceed: Bool {
        mapping.contains(.date) &&
        mapping.contains(where: { [.weight, .bodyFat, .muscleMass].contains($0) })
    }

    // MARK: - 3. 確認

    private var confirmingView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(validRows.count)件を取り込みます")
                            .font(.subheadline.weight(.semibold))
                        if rows.count > validRows.count {
                            Text("\(rows.count - validRows.count)件は日付または値が読み取れないため除外されます。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Text("同じ日に既存の記録がある場合は、値が空いている項目だけを埋めます。入力済みの値が上書きされることはありません。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal)

                if source == .photo && !recognizedLines.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("読み取れた文字")
                                .font(.caption.weight(.semibold))
                            Text(recognizedLines.prefix(12).joined(separator: " / "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                    .padding(.horizontal)
                }

                ForEach(validRows.prefix(50)) { row in
                    Card(padding: 12) {
                        HStack {
                            Text(row.date?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(row.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }

                if validRows.count > 50 {
                    Text("ほか \(validRows.count - 50)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - 処理

    private func handleFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let p = try CSVImporter.read(url: url)
            parsed = p
            mapping = ColumnMapper.guessMapping(headers: p.headers)
            stage = .mapping
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildRowsFromCSV() {
        guard let parsed else { return }
        rows = CSVImporter.buildRows(from: parsed, mapping: mapping)
        guard !rows.isEmpty else {
            errorMessage = "取り込める行が見つかりませんでした。列の対応を確認してください。"
            return
        }
        stage = .confirming
    }

    private func handlePhoto(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }

        #if canImport(Vision)
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "画像を読み込めませんでした。"
            return
        }
        guard let result = await OCRImporter.scan(image: image) else {
            errorMessage = "文字を読み取れませんでした。明るい場所で、結果表が画面いっぱいに写るように撮影してみてください。"
            return
        }
        guard result.row.hasValue else {
            errorMessage = "体重・体脂肪率・筋肉量のいずれも見つかりませんでした。別の写真でお試しください。"
            recognizedLines = result.recognizedLines
            return
        }
        rows = [result.row]
        recognizedLines = result.recognizedLines
        stage = .confirming
        #else
        errorMessage = "この端末では画像の読み取りに対応していません。"
        #endif
    }

    /// 既存の記録を壊さないよう、空いている項目だけを埋める
    private func commit() {
        let existing = (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        var added = 0, merged = 0

        for row in validRows {
            guard let date = row.date else { continue }

            if let match = existing.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: date)
            }) {
                var changed = false
                if match.weight == nil, let v = row.weight { match.weight = v; changed = true }
                if match.bodyFatPercentage == nil, let v = row.bodyFat { match.bodyFatPercentage = v; changed = true }
                if match.muscleMass == nil, let v = row.muscleMass { match.muscleMass = v; changed = true }
                if changed { merged += 1 }
            } else {
                context.insert(BodyMeasurement(
                    date: date,
                    weight: row.weight,
                    bodyFatPercentage: row.bodyFat,
                    muscleMass: row.muscleMass,
                    memo: source == .csv ? "CSVから取り込み" : "写真から取り込み"
                ))
                added += 1
            }
        }
        try? context.save()
        stage = .done
        dismiss()
    }
}
