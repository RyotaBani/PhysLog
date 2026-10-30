import SwiftUI
import SwiftData
import UIKit

// MARK: - コンディション共有

/// その日のコンディション記録・同じ日のトレーニング・「次に聞きたいこと」を
/// 1枚にまとめ、PDF または画像として共有するための画面。
///
/// トレーナーや医師に渡すことを想定している。外部サービスへは送らず、
/// 端末内で PDF / 画像を生成し、標準の共有シート（UIActivityViewController）に渡すだけ。
struct ConditionShareView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let record: ConditionRecord

    /// 同じ日に記録されたトレーニング。日付のレンジで引く（リレーションは持たない）。
    @State private var sameDaySessions: [TrainingSession] = []
    /// 共有シートに渡すファイル。生成できたときだけ入る。
    @State private var sharePayload: SharePayload? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                // プレビューと共有に同じ View を使い、見たままが渡るようにする。
                ConditionReportCard(record: record, sessions: sameDaySessions)
                    .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        share(.pdf)
                    } label: {
                        Label("PDFで共有", systemImage: "doc.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.physlogPrimary)

                    Button {
                        share(.image)
                    } label: {
                        Label("画像で共有", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.physlogPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .navigationTitle("記録を共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: [payload.url])
            }
            .onAppear(perform: loadSameDaySessions)
        }
    }

    // MARK: - 同日のトレーニングを取得

    private func loadSameDaySessions() {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: record.date)
        // 翌日の 0 時までを「その日」とする
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return }

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd },
            sortBy: [SortDescriptor(\.date)]
        )
        sameDaySessions = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 共有

    private enum ShareFormat { case pdf, image }

    @MainActor
    private func share(_ format: ShareFormat) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: record.date)

        // 共有用はプレビューと同じ中身。白背景＋余白を付けて書き出す。
        let content = ConditionReportCard(record: record, sessions: sameDaySessions)
            .frame(width: 540)
            .padding(24)
            .background(Color.white)

        let url: URL?
        switch format {
        case .pdf:
            url = ReportRenderer.makePDF(content, fileName: "PhysLog_体調_\(dateStr).pdf")
        case .image:
            url = ReportRenderer.makePNG(content, fileName: "PhysLog_体調_\(dateStr).png")
        }

        if let url {
            sharePayload = SharePayload(url: url)
        }
    }
}

// MARK: - 共有シートに渡すファイル

/// URL は Identifiable ではないため、.sheet(item:) 用に包む。
private struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - レポート本体（PDF・画像・プレビュー共通）

/// 1枚の共有用レイアウト。ImageRenderer で確実に描けるよう、
/// 凝ったコンポーネントは避けてプレーンな SwiftUI で組む。
struct ConditionReportCard: View {
    let record: ConditionRecord
    let sessions: [TrainingSession]

    private var fullDate: String {
        record.date.formatted(
            .dateTime.year().month().day().weekday(.abbreviated)
                .locale(Locale(identifier: "ja_JP"))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // ヘッダー
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("コンディション記録")
                        .font(.title3.weight(.bold))
                    Text(fullDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("PhysLog")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.physlogPrimary)
            }

            Divider()

            // コンディション
            section(title: "コンディション") {
                reportRow(icon: "moon.fill", label: "睡眠", value: record.sleepLabel, color: .physlogPurple)
                reportRow(icon: "bolt.fill", label: "疲労度", value: record.fatigueLabel, color: .physlogOrange)
                reportRow(icon: "heart.fill", label: "体調",
                          value: "\(record.conditionEmoji) \(record.conditionLabel)", color: .physlogPink)
            }

            // メモ
            if !record.memo.isEmpty {
                section(title: "メモ") {
                    Text(record.memo)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // その日のトレーニング
            section(title: "この日のトレーニング") {
                if sessions.isEmpty {
                    Text("記録なし")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(session.displayTitle)
                                        .font(.subheadline.weight(.semibold))
                                    if !session.gymName.isEmpty {
                                        Text("＠\(session.gymName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                ForEach(session.sortedExercises) { set in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("・\(set.exercise)")
                                            .font(.footnote)
                                        Spacer(minLength: 8)
                                        Text(set.summary)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 次に聞きたいこと
            if !record.questions.isEmpty {
                section(title: "次に聞きたいこと") {
                    Text(record.questions)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.physlogPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            Divider()

            Text("PhysLog で記録")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
    }

    // MARK: - 小さな組み立てヘルパー

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func reportRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

// MARK: - View を PDF / 画像に書き出す

/// ImageRenderer（iOS 16+）で SwiftUI View をファイル化する。
/// 端末内で完結し、外部へは送らない。
@MainActor
enum ReportRenderer {

    static func makePDF(_ view: some View, fileName: String) -> URL? {
        let renderer = ImageRenderer(content: view)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var succeeded = false
        renderer.render { size, renderInContext in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            renderInContext(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            succeeded = true
        }
        return succeeded ? url : nil
    }

    static func makePNG(_ view: some View, fileName: String) -> URL? {
        let renderer = ImageRenderer(content: view)
        // 画面より高精細で書き出し、拡大しても粗くならないようにする
        renderer.scale = 3
        guard let image = renderer.uiImage,
              let data = image.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("PNG export failed: \(error)")
            return nil
        }
    }
}

#Preview {
    ConditionShareView(record: ConditionRecord(
        date: Date(),
        sleepHours: 7.5,
        fatigue: 2,
        condition: 2,
        memo: "右膝に軽い違和感。アップを長めに取った。",
        questions: "練習後の膝の違和感について、続けてよいか相談したい。"
    ))
    .modelContainer(PreviewData.container)
}
