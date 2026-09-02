import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store

    @AppStorage("userName")  private var userName = ""
    @AppStorage("userSport") private var userSport = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Query private var measurements: [BodyMeasurement]
    @Query private var abilities: [PhysicalAbility]
    @Query private var sessions: [TrainingSession]
    @Query private var conditions: [ConditionRecord]

    @State private var showDeleteAlert = false
    @State private var showSampleAlert = false
    @State private var exportURL: URL? = nil
    @State private var showPaywall = false
    @State private var restoreMessage: String?
    @State private var health = HealthKitManager.shared
    @State private var healthMessage: String?
    @State private var importSource: ImportView.Source?

    private var totalRecords: Int {
        measurements.count + abilities.count + sessions.count + conditions.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("プロフィール") {
                    HStack {
                        Label("名前", systemImage: "person.fill")
                        Spacer()
                        TextField("未設定", text: $userName)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("競技", systemImage: "sportscourt.fill")
                        Spacer()
                        TextField("バスケットボール など", text: $userSport)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    CountRow(label: "身体測定", count: measurements.count,
                             icon: "scalemass.fill", color: .physlogPrimary)
                    CountRow(label: "身体能力", count: abilities.count,
                             icon: "figure.run", color: .physlogAccent)
                    CountRow(label: "トレーニング", count: sessions.count,
                             icon: "dumbbell.fill", color: .physlogOrange)
                    CountRow(label: "コンディション", count: conditions.count,
                             icon: "heart.fill", color: .physlogPink)
                } header: {
                    Text("記録件数")
                } footer: {
                    Text("合計 \(totalRecords) 件のデータが端末内に保存されています")
                }

                Section {
                    switch health.status {
                    case .unavailable:
                        Label("この端末はヘルスケアに対応していません", systemImage: "heart.slash")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)

                    case .notRequested, .denied:
                        Button {
                            Task {
                                await health.requestAuthorization()
                                if health.status == .authorized {
                                    await health.importAll(into: context)
                                    healthMessage = health.lastResult?.message
                                }
                            }
                        } label: {
                            Label("ヘルスケアと連携", systemImage: "heart.text.square.fill")
                        }

                    case .authorized:
                        Button {
                            Task {
                                await health.importAll(into: context)
                                healthMessage = health.lastResult?.message
                            }
                        } label: {
                            HStack {
                                Label("ヘルスケアから取り込む", systemImage: "arrow.down.heart.fill")
                                Spacer()
                                if health.isImporting { ProgressView() }
                            }
                        }
                        .disabled(health.isImporting)
                    }
                    Button {
                        importSource = .csv
                    } label: {
                        Label("CSVから取り込む", systemImage: "doc.text")
                    }

                    Button {
                        importSource = .photo
                    } label: {
                        Label("写真から取り込む", systemImage: "camera.viewfinder")
                    }
                } header: {
                    Text("データの取り込み")
                } footer: {
                    Text("ヘルスケアからは体重・体脂肪率・睡眠時間が入ります。筋肉量はヘルスケアで扱われないため、CSVまたは写真から取り込んでください。\n\nいずれの経路でも、入力済みの記録が上書きされることはありません。")
                }

                Section {
                    Button {
                        exportCSV()
                    } label: {
                        Label("CSVで書き出す", systemImage: "square.and.arrow.up")
                    }
                    .disabled(totalRecords == 0)

                    Button {
                        showSampleAlert = true
                    } label: {
                        Label("デモデータを追加", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("データ")
                } footer: {
                    Text("デモデータは過去3ヶ月分のサンプル記録を追加します。グラフの表示確認に使えます。")
                }

                Section {
                    LabeledContent("バージョン", value: "1.0.0")
                    LabeledContent("保存先", value: "この端末のみ")

                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("アプリの紹介をもう一度見る", systemImage: "sparkles.rectangle.stack")
                    }

                    Link(destination: URL(string: "https://ryotabani.github.io/physlog/privacy.html")!) {
                        HStack {
                            Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://ryotabani.github.io/physlog/support.html")!) {
                        HStack {
                            Label("サポート", systemImage: "questionmark.circle.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("アプリ情報")
                } footer: {
                    Text("記録したデータはすべて端末内に保存され、外部サーバーへは送信されません。ただし広告の配信のため、広告事業者が識別子等を取得します。")
                }

                // v1.0 は完全無料 + 広告で提供するため、課金導線は表示しない。
                // FeatureFlags.isProEnabled を true にすれば復活する。
                if FeatureFlags.isProEnabled {
                    Section {
                        if store.isPro {
                            HStack {
                                Label {
                                    Text("PhysLog Pro")
                                } icon: {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Color.physlogPrimary)
                                }
                                Spacer()
                                Text("利用中")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                Label("サブスクリプションを管理", systemImage: "creditcard")
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Label {
                                        Text("PhysLog Pro にアップグレード")
                                    } icon: {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(Color.physlogPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Button {
                                Task {
                                    let ok = await store.restore()
                                    restoreMessage = ok
                                        ? "購入を復元しました。"
                                        : "このApple IDでの購入履歴が見つかりませんでした。"
                                }
                            } label: {
                                Label("購入を復元", systemImage: "arrow.clockwise")
                            }
                        }
                    } header: {
                        Text("Pro")
                    } footer: {
                        Text(store.isPro
                             ? "コンディション分析をご利用いただけます。広告は表示されません。"
                             : "Proにすると、睡眠や疲労とパフォーマンスの関係を分析でき、広告が非表示になります。")
                    }
                }

                // 広告を表示するため、トラッキング設定への導線は常に用意する
                Section {
                    #if canImport(AppTrackingTransparency)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("トラッキング設定を変更", systemImage: "hand.raised.fill")
                    }
                    #endif
                } header: {
                    Text("広告")
                } footer: {
                    Text("PhysLog は広告収入によって完全無料で提供されています。トラッキングを許可しない場合も、広告は表示されますが、すべての機能を制限なくご利用いただけます。")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("すべてのデータを削除", systemImage: "trash.fill")
                    }
                    .disabled(totalRecords == 0)
                }
            }
            .adBanner()
            .navigationTitle("設定")
            .alert("すべてのデータを削除しますか？", isPresented: $showDeleteAlert) {
                Button("削除", role: .destructive) {
                    SampleData.deleteAll(from: context)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(totalRecords) 件の記録がすべて失われます。この操作は取り消せません。")
            }
            .alert("デモデータを追加しますか？", isPresented: $showSampleAlert) {
                Button("追加") {
                    SampleData.populate(into: context)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("過去3ヶ月分のサンプル記録が既存データに追加されます。")
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: $importSource) { source in
                ImportView(source: source)
            }
            .alert("ヘルスケア", isPresented: .constant(healthMessage != nil)) {
                Button("OK") { healthMessage = nil }
            } message: {
                Text(healthMessage ?? "")
            }
            .alert("購入の復元", isPresented: .constant(restoreMessage != nil)) {
                Button("OK") { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
            .sheet(item: Binding(
                get: { exportURL.map { ExportFile(url: $0) } },
                set: { exportURL = $0?.url }
            )) { file in
                ShareSheet(items: [file.url])
            }
        }
    }

    // MARK: - CSV 書き出し

    private func exportCSV() {
        var lines = ["種別,日付,項目,値1,値2,値3,メモ"]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for m in measurements.sorted(by: { $0.date < $1.date }) {
            lines.append([
                "身体測定", df.string(from: m.date), "",
                m.weight.map { String($0) } ?? "",
                m.bodyFatPercentage.map { String($0) } ?? "",
                m.muscleMass.map { String($0) } ?? "",
                escape(m.memo)
            ].joined(separator: ","))
        }

        for a in abilities.sorted(by: { $0.date < $1.date }) {
            lines.append([
                "身体能力", df.string(from: a.date), escape(a.type),
                String(a.value), a.unit, "", escape(a.memo)
            ].joined(separator: ","))
        }

        for s in sessions.sorted(by: { $0.date < $1.date }) {
            for set in s.sortedExercises {
                lines.append([
                    "トレーニング", df.string(from: s.date), escape(set.exercise),
                    set.weight.map { String($0) } ?? "",
                    set.reps.map { String($0) } ?? "",
                    set.sets.map { String($0) } ?? "",
                    escape(s.memo)
                ].joined(separator: ","))
            }
        }

        for c in conditions.sorted(by: { $0.date < $1.date }) {
            lines.append([
                "コンディション", df.string(from: c.date), "",
                c.sleepHours.map { String($0) } ?? "",
                c.fatigue.map { String($0) } ?? "",
                c.condition.map { String($0) } ?? "",
                escape(c.memo)
            ].joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n")
        let filename = "PhysLog_\(df.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        // Excel での文字化けを防ぐため BOM を付与
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(csv.data(using: .utf8) ?? Data())

        do {
            try data.write(to: url)
            exportURL = url
        } catch {
            print("CSV export failed: \(error)")
        }
    }

    private func escape(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - 部品

struct CountRow: View {
    let label: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            Spacer()
            Text("\(count) 件")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
        .environment(ProStore.shared)
}
