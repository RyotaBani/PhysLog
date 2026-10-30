import SwiftUI
import SwiftData

struct ConditionListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ConditionRecord.date, order: .reverse) private var records: [ConditionRecord]

    @State private var editing: ConditionRecord? = nil
    @State private var isAdding = false
    @State private var sharing: ConditionRecord? = nil

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(
                    icon: "heart.text.square",
                    title: "コンディションの記録がありません",
                    message: "睡眠・疲労度・体調を残しておくと、\nパフォーマンスとの関係が見えてきます"
                )
            } else {
                List {
                    ForEach(records) { record in
                        Button {
                            editing = record
                        } label: {
                            ConditionRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        // 左スワイプで、その日の記録をまとめて共有できる
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                sharing = record
                            } label: {
                                Label("共有", systemImage: "square.and.arrow.up")
                            }
                            .tint(.physlogPrimary)
                        }
                        .contextMenu {
                            Button {
                                sharing = record
                            } label: {
                                Label("共有用にまとめる", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(records[index]) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

        }
        .floatingAddButton { isAdding = true }
        .sheet(isPresented: $isAdding) {
            ConditionEditor(record: nil)
        }
        .sheet(item: $editing) { record in
            ConditionEditor(record: record)
        }
        .sheet(item: $sharing) { record in
            ConditionShareView(record: record)
        }
    }
}

// MARK: - 行

struct ConditionRow: View {
    let record: ConditionRecord

    private var badgeColor: Color {
        switch record.condition {
        case 1: return .physlogAccent
        case 2: return .physlogPrimary
        case 3: return .physlogOrange
        case 4: return .orange
        case 5: return .physlogPink
        default: return .gray
        }
    }

    var body: some View {
        Card(padding: 14) {
            VStack(spacing: 12) {
                HStack {
                    Text("\(record.date.shortJP)（\(record.date.weekdayJP)）")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(record.conditionEmoji) \(record.conditionLabel)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(badgeColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(badgeColor)
                }

                HStack(spacing: 0) {
                    ConditionCell(icon: "moon.fill", label: "睡眠", value: record.sleepLabel, color: .physlogPurple)
                    Divider().frame(height: 34)
                    ConditionCell(icon: "bolt.fill", label: "疲労度", value: record.fatigueLabel, color: .physlogOrange)
                    Divider().frame(height: 34)
                    ConditionCell(icon: "heart.fill", label: "体調", value: record.conditionLabel, color: .physlogPink)
                }

                if !record.memo.isEmpty {
                    Text(record.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !record.questions.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.physlogPrimary)
                        Text(record.questions)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct ConditionCell: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 追加・編集

struct ConditionEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let record: ConditionRecord?

    @State private var date = Date()
    @State private var sleep = ""
    @State private var fatigue: Int? = nil
    @State private var condition: Int? = nil
    @State private var memo = ""
    @State private var questions = ""

    private var canSave: Bool {
        !sleep.isEmpty || fatigue != nil || condition != nil || !questions.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section("睡眠") {
                    NumberInputRow(label: "睡眠時間", placeholder: "7.5", unit: "h", text: $sleep)
                }

                Section {
                    ScalePicker(
                        title: "疲労度",
                        lowLabel: "1 ほぼなし",
                        highLabel: "5 非常に高い",
                        color: .physlogOrange,
                        value: $fatigue
                    )
                    .padding(.vertical, 4)

                    ScalePicker(
                        title: "体調",
                        lowLabel: "1 最高",
                        highLabel: "5 不調",
                        color: .physlogPink,
                        value: $condition
                    )
                    .padding(.vertical, 4)
                } header: {
                    Text("コンディション")
                } footer: {
                    Text("同じ数字をもう一度タップすると選択を解除できます")
                }

                Section("メモ") {
                    TextField("気になる症状・生活の変化など", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    TextField("例：練習後の膝の違和感について相談したい", text: $questions, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("次に聞きたいこと")
                } footer: {
                    Text("トレーナーや医師に相談したいことをメモしておくと、記録と一緒にまとめて共有できます")
                }
            }
            .navigationTitle(record == nil ? "コンディションを記録" : "記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let record else { return }
        date = record.date
        sleep = record.sleepHours.map { String($0) } ?? ""
        fatigue = record.fatigue
        condition = record.condition
        memo = record.memo
        questions = record.questions
    }

    private func save() {
        if let record {
            record.date = date
            record.sleepHours = Double(sleep)
            record.fatigue = fatigue
            record.condition = condition
            record.memo = memo
            record.questions = questions
        } else {
            context.insert(ConditionRecord(
                date: date,
                sleepHours: Double(sleep),
                fatigue: fatigue,
                condition: condition,
                memo: memo,
                questions: questions
            ))
        }
        dismiss()
    }
}

#Preview {
    ConditionListView()
        .modelContainer(PreviewData.container)
}
