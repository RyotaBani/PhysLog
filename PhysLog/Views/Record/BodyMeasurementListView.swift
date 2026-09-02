import SwiftUI
import SwiftData

struct BodyMeasurementListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var records: [BodyMeasurement]

    @State private var editing: BodyMeasurement? = nil
    @State private var isAdding = false

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(
                    icon: "scalemass",
                    title: "身体測定の記録がありません",
                    message: "右下の + から体重・体脂肪率・筋肉量を記録できます"
                )
            } else {
                List {
                    ForEach(records) { record in
                        Button {
                            editing = record
                        } label: {
                            BodyMeasurementRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
            BodyMeasurementEditor(record: nil)
        }
        .sheet(item: $editing) { record in
            BodyMeasurementEditor(record: record)
        }
    }
}

// MARK: - 行

struct BodyMeasurementRow: View {
    let record: BodyMeasurement

    var body: some View {
        Card(padding: 14) {
            VStack(spacing: 12) {
                HStack {
                    Text(record.date.shortJP)
                        .font(.subheadline.weight(.semibold))
                    Text("(\(record.date.weekdayJP))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !record.memo.isEmpty {
                        Image(systemName: "text.alignleft")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 0) {
                    MetricCell(label: "体重", value: record.weight, unit: "kg", color: .physlogPrimary)
                    Divider().frame(height: 34)
                    MetricCell(label: "体脂肪率", value: record.bodyFatPercentage, unit: "%", color: .physlogOrange)
                    Divider().frame(height: 34)
                    MetricCell(label: "筋肉量", value: record.muscleMass, unit: "kg", color: .physlogAccent)
                }

                if !record.memo.isEmpty {
                    Text(record.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct MetricCell: View {
    let label: String
    let value: Double?
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let value {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text(String(format: "%.1f", value))
                        .font(.headline)
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 追加・編集

struct BodyMeasurementEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let record: BodyMeasurement?

    @State private var date = Date()
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var muscle = ""
    @State private var memo = ""

    private var canSave: Bool {
        !(weight.isEmpty && bodyFat.isEmpty && muscle.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section("計測値") {
                    NumberInputRow(label: "体重", placeholder: "68.5", unit: "kg", text: $weight)
                    NumberInputRow(label: "体脂肪率", placeholder: "16.0", unit: "%", text: $bodyFat)
                    NumberInputRow(label: "筋肉量", placeholder: "52.0", unit: "kg", text: $muscle)
                }

                Section("メモ") {
                    TextField("体調や測定条件など", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(record == nil ? "身体測定を記録" : "記録を編集")
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
        weight = record.weight.map { String($0) } ?? ""
        bodyFat = record.bodyFatPercentage.map { String($0) } ?? ""
        muscle = record.muscleMass.map { String($0) } ?? ""
        memo = record.memo
    }

    private func save() {
        let w = Double(weight)
        let f = Double(bodyFat)
        let m = Double(muscle)

        if let record {
            record.date = date
            record.weight = w
            record.bodyFatPercentage = f
            record.muscleMass = m
            record.memo = memo
        } else {
            context.insert(BodyMeasurement(
                date: date, weight: w, bodyFatPercentage: f, muscleMass: m, memo: memo
            ))
        }
        dismiss()
    }
}

#Preview {
    BodyMeasurementListView()
        .modelContainer(PreviewData.container)
}
